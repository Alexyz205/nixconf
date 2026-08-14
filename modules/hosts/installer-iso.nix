{
  inputs,
  self,
  ...
}: let
  diskoPkg = inputs.disko.packages.x86_64-linux.disko;
in {
  flake.nixosConfigurations.workstation-iso = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit diskoPkg; };
    modules = [
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
      ({
        lib,
        pkgs,
        diskoPkg,
        ...
      }: let
        installerScript = pkgs.writeShellScriptBin "nixos-installer" ''
          set -Eeuo pipefail
          export VERBOSE="''${VERBOSE:-0}"
          LOGFILE="''${LOGFILE:-/tmp/nixos-installer.log}"
          if [[ "$VERBOSE" = 1 ]]; then set -x; fi

          if [[ "$(id -u)" -ne 0 ]]; then
            echo "Error: nixos-installer must be run as root (try: sudo nixos-installer)" >&2
            exit 1
          fi

          FLAKE_DIR="/iso/nixconf"

          step() {
            gum log --structured --level info --time timeonly "  • $*"
          }
          ok() {
            gum log --structured --level info "OK: $*"
          }
          fail() {
            gum log --structured --level error "$*" >&2
            echo "Error: $*" >>"$LOGFILE"
            exit 1
          }

          trap 'e=$?; gum log --structured --level error "Failed at line $LINENO: $BASH_COMMAND (exit $e)" >&2; echo "FAILED line $LINENO: $BASH_COMMAND (exit $e)" >>"$LOGFILE"; exit $e' ERR

          echo
          echo "Installer log: $LOGFILE (verbatim command output below)." >&2
          echo

          gum style \
            --foreground 212 --border-foreground 212 --border double \
            --align center --width 60 \
            "nixconf installer"

          echo

          step "Selecting host"
          HOST=$(gum choose --header "Which host to install?" headless-worker workstation)
          ok "Selected host: $HOST"

          USERNAME=$(nix eval "$FLAKE_DIR#$HOST.config.modules.users.userName" --raw 2>/dev/null || echo "alexis")

          echo
          if [[ "$HOST" == "workstation" ]]; then
            step "YubiKey setup"
            USE_YUBIKEY=$(gum choose --header "Use YubiKey for disk encryption and login?" "No" "Yes")
            if [[ "$USE_YUBIKEY" == "Yes" ]]; then
              gum log --structured --level warn "Plug in your YubiKey now"
              gum log --structured --level info "Waiting for YubiKey..."
              for i in $(seq 1 30); do
                if lsusb 2>/dev/null | grep -qi yubico || compgen -G '/dev/hidraw*' >/dev/null; then
                  gum log --structured --level info "YubiKey detected"
                  break
                fi
                if [[ "$i" -ge 30 ]]; then
                  fail "YubiKey not detected after 30s"
                fi
                sleep 1
              done
              ok "YubiKey detected"
              ENROLL_FIDO2="true"
            else
              gum log --structured --level info "Skipping YubiKey — password-only LUKS and sudo"
              ENROLL_FIDO2="false"
            fi
          else
            gum log --structured --level info "Skipping YubiKey — not used on headless servers"
            USE_YUBIKEY="No"
            ENROLL_FIDO2="false"
          fi

          echo
          step "Listing disks"
          DISK_INFO=$(lsblk -d -n -o NAME,SIZE,TYPE,MODEL 2>/dev/null | grep -v loop | grep -v ram || true)
          if [[ -z "$DISK_INFO" ]]; then
            fail "No disks found"
          fi

          DISK_NAME=$(echo "$DISK_INFO" | gum choose --header "Select target disk:" | awk '{print $1}')
          DISK="/dev/$DISK_NAME"
          ok "Target disk: $DISK"

          echo
          gum style --foreground 3 --bold "WARNING"
          gum style --foreground 3 "ALL DATA on $DISK will be DESTROYED."

          gum confirm "Are you sure?" || fail "Aborted by user"

          echo
          step "Checking flake"
          if [[ ! -d "$FLAKE_DIR" ]]; then
            fail "Flake directory $FLAKE_DIR not found. ISO may be misconfigured."
          fi
          ok "Flake pre-baked in ISO"

          echo
          step "Checking network"
          gum log --structured --level info "Waiting for network..."
          for i in $(seq 1 30); do
            if ping -c 1 -W 1 github.com >/dev/null 2>&1; then
              break
            fi
            if [[ "$i" -ge 30 ]]; then
              gum log --structured --level error "No network after 30s"
              fail "No network. Connect Ethernet and retry."
            fi
            sleep 1
          done
          ok "Network reachable"

          echo
          step "User password"
          PASSWD=""
          for i in 1 2 3; do
            P1=$(gum input --password --placeholder "Enter password for $USERNAME")
            P2=$(gum input --password --placeholder "Confirm password")
            if [[ "$P1" == "$P2" && -n "$P1" ]]; then
              PASSWD="$P1"
              ok "Password accepted"
              break
            fi
            gum log --structured --level error "Passwords do not match or empty (attempt $i/3)"
            [[ "$i" -ge 3 ]] && fail "Failed to set password after 3 attempts"
          done

          echo
          step "Confirming installation"
          gum style --foreground 212 --bold "Installation Summary"
          echo "  Host:      $HOST"
          echo "  Disk:      $DISK"
          echo "  User:      $USERNAME"
          echo "  YubiKey:   $USE_YUBIKEY"
          echo "  Source:    $FLAKE_DIR#$HOST"
          echo

          gum confirm "Begin installation?" || fail "Aborted by user"

          echo
          step "Partitioning and formatting disk"
          gum log --structured --level info "Generating disk layout for $DISK..."

          cat > /tmp/disko-config.nix << 'NIXEOF'
          { device, enrollFido2 ? false, lib, ... }:
          let
            flake = builtins.getFlake "/iso/nixconf";
            cfg = flake.nixosConfigurations."__HOST__".config.disko;
            main = lib.filterAttrsRecursive (n: _: !lib.hasPrefix "_" n && n != "device") cfg.devices.disk.main;
            parts = main.content.partitions;
            hasLuks = parts ? luks;
            contentOverride = if hasLuks then main.content // {
              partitions = parts // {
                luks = parts.luks // {
                  content = parts.luks.content // {
                    inherit enrollFido2;
                    enrollRecovery = enrollFido2;
                  };
                };
              };
            } else main.content;
          in {
            disko.devices.disk.main = {
              inherit (main) type;
              device = device;
              content = contentOverride;
            };
          }
        NIXEOF
          sed -i "s/__HOST__/$HOST/" /tmp/disko-config.nix

          gum log --structured --level info "Running disko (this will take a while)..."
          disko --mode destroy,format,mount /tmp/disko-config.nix \
            --argstr device "$DISK" \
            --arg enrollFido2 "$ENROLL_FIDO2" \
            --yes-wipe-all-disks \
            2>&1 | tee -a "$LOGFILE"
          ok "Disk partitioned and mounted"

          echo
          step "Installing NixOS"
          gum log --structured --level info "Building system..."

          cat > /tmp/build-system.nix << 'NIXEOF'
          { device, withYubiKey ? true, ... }:
          let
            flake = builtins.getFlake "/iso/nixconf";
            original = flake.nixosConfigurations."__HOST__";
            hasYubiKey = original.options.modules ? yubikey;
          in
            (original.extendModules {
              modules = [
                ({ lib, ... }: {
                  disko.devices.disk.main.device = lib.mkForce device;
                  boot.loader.efi.canTouchEfiVariables = lib.mkForce true;
                } // lib.optionalAttrs (!withYubiKey && hasYubiKey) {
                  modules.yubikey.luksUnlock = lib.mkForce false;
                  modules.yubikey.sudoAuth = lib.mkForce false;
                })
              ];
            }).config.system.build.toplevel
        NIXEOF
          sed -i "s/__HOST__/$HOST/" /tmp/build-system.nix

          YUBI_NIX_ARG=$([ "$USE_YUBIKEY" = "Yes" ] && echo "--arg withYubiKey true" || echo "--arg withYubiKey false")
          SYSTEM=$(nix-build --extra-experimental-features 'nix-command flakes' \
            /tmp/build-system.nix \
            --argstr device "$DISK" \
            $YUBI_NIX_ARG \
            --no-out-link)

          gum log --structured --level info "Running nixos-install..."
          nixos-install --no-root-passwd --system "$SYSTEM" --root /mnt 2>&1 | tee -a "$LOGFILE"
          ok "NixOS installed"

          echo
          step "Copying flake to installed system"
          cp -a "$FLAKE_DIR" /mnt/etc/nixos
          ok "Flake copied to /mnt/etc/nixos"

          echo
          step "Setting password for $USERNAME"
          echo "$USERNAME:$PASSWD" | chpasswd -R /mnt
          ok "Password set for $USERNAME"

          if [[ "$USE_YUBIKEY" == "Yes" ]]; then
            echo
            step "Enrolling YubiKey for login/sudo"
            gum log --structured --level info "Touch your YubiKey when it flashes..."
            mkdir -p /mnt/home/$USERNAME/.config/Yubico
            pamu2fcfg -o /mnt/home/$USERNAME/.config/Yubico/u2f_keys
            ok "YubiKey enrolled for PAM authentication"
          fi

          echo
          gum style \
            --foreground 2 --border-foreground 2 --border double \
            --align center --width 60 \
            "Installation complete."

          echo
          gum log --structured --level info "Remove the USB drive and reboot."
          gum log --structured --level info "Login as '$USERNAME' with the password you just set."
          if [[ "$USE_YUBIKEY" == "Yes" ]]; then
            gum log --structured --level info "YubiKey is configured for LUKS unlock and sudo auth."
          fi
        '';
      in {
        nixpkgs.hostPlatform = "x86_64-linux";
        isoImage = {
          edition = "custom-iso";
          contents = [
            {
              source = self.sourceInfo.outPath;
              target = "/nixconf";
            }
          ];
        };

        nix.settings.experimental-features = [ "nix-command" "flakes" ];

        services.openssh.enable = true;
        users.users.root = {
          initialHashedPassword = lib.mkForce null;
          password = "nixos";
        };

        environment.etc."yubi-age-identity".source = ../config/sops/yubi-age-identity;

        services.udev.packages = [pkgs.yubikey-personalization];

        environment.systemPackages = [
          pkgs.gum
          pkgs.libfido2
          pkgs.pam_u2f
          pkgs.usbutils
          diskoPkg
          installerScript
        ];

        users.motd = ''
          ============================================
          nixconf installer
          ============================================

          Run 'nixos-installer' to begin installation.
        '';
      })
    ];
  };
}
