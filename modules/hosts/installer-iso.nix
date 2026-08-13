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
          gum log --structured --level debug "Running gum choose for host"
          HOST=$(gum choose --header "Which host to install?" headless-worker workstation)
          ok "Selected host: $HOST"

          USERNAME=$(nix eval "$FLAKE_DIR#$HOST.config.modules.users.userName" --raw 2>/dev/null || echo "alexis")
          gum log --structured --level debug "Username: $USERNAME"

          echo
          step "Insert YubiKey"
          gum log --structured --level warn "Plug in your YubiKey now (needed for LUKS enrollment)"
          gum log --structured --level info "Waiting for YubiKey..."
          for i in $(seq 1 30); do
            if lsusb 2>/dev/null | grep -qi yubico || compgen -G '/dev/hidraw*' >/dev/null; then
              gum log --structured --level debug "YubiKey detected after ''${i}s"
              break
            fi
            if [[ "$i" -ge 30 ]]; then
              gum log --structured --level warn "YubiKey not detected — LUKS will prompt for password"
            fi
            sleep 1
          done
          ok "Proceeding with disk setup"

          echo
          step "Listing disks"
          DISK_INFO=$(lsblk -d -n -o NAME,SIZE,TYPE,MODEL 2>/dev/null | grep -v loop | grep -v ram || true)
          gum log --structured --level debug "lsblk output: [$DISK_INFO]"
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
          gum log --structured --level debug "Flake present at $FLAKE_DIR"
          ok "Flake pre-baked in ISO"

          echo
          step "Checking network"
          gum log --structured --level info "Waiting for network..."
          for i in $(seq 1 30); do
            if ping -c 1 -W 1 github.com >/dev/null 2>&1; then
              gum log --structured --level debug "Network up after ''${i}s"
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
          step "Confirming installation"
          gum style --foreground 212 --bold "Installation Summary"
          echo "  Host:   $HOST"
          echo "  Disk:   $DISK"
          echo "  Source: $FLAKE_DIR#$HOST"
          echo

          gum confirm "Begin installation?" || fail "Aborted by user"

          step "Running disko-install (long)"
          gum log --structured --level info "Starting disko-install (this will take a while)..."
          disko-install \
            --flake "$FLAKE_DIR#$HOST" \
            --disk main "$DISK" \
            --write-efi-boot-entries \
            --extra-files "$FLAKE_DIR" /etc/nixos 2>&1 | tee -a "$LOGFILE"
          ok "disko-install completed"

          echo
          step "Setting password for $USERNAME"
          gum log --structured --level info "Setting password for user '$USERNAME'"
          if ! mountpoint -q /mnt 2>/dev/null; then
            fail "Target root (/mnt) not found after disko-install"
          fi
          for i in 1 2 3; do
            PASSWD=$(gum input --password --placeholder "Enter password for $USERNAME")
            PASSWD_CONFIRM=$(gum input --password --placeholder "Confirm password")
            if [[ "$PASSWD" == "$PASSWD_CONFIRM" && -n "$PASSWD" ]]; then
              echo "$USERNAME:$PASSWD" | chpasswd -R /mnt
              ok "Password set for $USERNAME"
              break
            fi
            gum log --structured --level error "Passwords do not match or empty (attempt $i/3)"
            [[ "$i" -ge 3 ]] && fail "Failed to set password after 3 attempts"
          done

          echo
          step "Enrolling YubiKey for login/sudo"
          gum log --structured --level info "Touch your YubiKey when it flashes..."
          mkdir -p /mnt/home/$USERNAME/.config/Yubico
          pamu2fcfg -o /mnt/home/$USERNAME/.config/Yubico/u2f_keys
          ok "YubiKey enrolled for PAM authentication"

          echo
          gum style \
            --foreground 2 --border-foreground 2 --border double \
            --align center --width 60 \
            "Installation complete."

          echo
          gum log --structured --level info "Remove the USB drive and reboot."
          gum log --structured --level info "Login as '$USERNAME' with the password you just set."
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
