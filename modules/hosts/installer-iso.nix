{
  inputs,
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
          export GIT_TERMINAL_PROMPT=0
          if [[ "$VERBOSE" = 1 ]]; then set -x; fi

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

          # Every unexpected failure -> print the exact line + command, never silent.
          trap 'e=$?; gum log --structured --level error "Failed at line $LINENO: $BASH_COMMAND (exit $e)" >&2; echo "FAILED line $LINENO: $BASH_COMMAND (exit $e)" >>"$LOGFILE"; exit $e' ERR
          trap '[[ -n "''${SCRATCH_DIR:-}" ]] && rm -rf "$SCRATCH_DIR"' EXIT

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
          step "Checking YubiKey"
          gum log --structured --level debug "Running ykman info"
          if ! ykman info 2>&1 | tee -a "$LOGFILE"; then
            fail "YubiKey not detected. Plug it in and retry."
          fi
          ok "YubiKey present"

          step "Starting ssh-agent"
          eval "$(ssh-agent -s)"
          gum log --structured --level debug "SSH_AUTH_SOCK=$SSH_AUTH_SOCK SSH_AGENT_PID=$SSH_AGENT_PID"

          echo
          step "Recovering FIDO2 resident key"
          mkdir -p ~/.ssh
          SCRATCH_DIR="$(mktemp -d)"
          gum log --structured --level info "Running ssh-keygen -K in $SCRATCH_DIR. Enter your PIN when prompted."
          if ! (cd "$SCRATCH_DIR" && ssh-keygen -K) 2>&1 | tee -a "$LOGFILE"; then
            gum log --structured --level error "ssh-keygen -K failed"
            fail "Key recovery failed. Is this a discoverable (resident) FIDO2 key?"
          fi

          RECOVERED_KEYS="$(find "$SCRATCH_DIR" -maxdepth 1 -name 'id_*_sk*' -type f | sort)"
          gum log --structured --level debug "Recovered files: $RECOVERED_KEYS"
          if [[ -z "$RECOVERED_KEYS" ]]; then
            gum log --structured --level error "No FIDO2 key recovered in $SCRATCH_DIR"
            fail "Key recovery failed. No id_*_sk* file was produced."
          fi

          step "Normalizing key name to id_ed25519_sk_rk_alexis-perso (OpenSSH convention)"
          FIRST_KEY="$(echo "$RECOVERED_KEYS" | head -1)"
          cp -v "$FIRST_KEY" ~/.ssh/id_ed25519_sk_rk_alexis-perso 2>&1 | tee -a "$LOGFILE"
          cp -v "$FIRST_KEY.pub" ~/.ssh/id_ed25519_sk_rk_alexis-perso.pub 2>&1 | tee -a "$LOGFILE"
          chmod 600 ~/.ssh/id_ed25519_sk_rk_alexis-perso
          gum log --structured --level debug "Copied $FIRST_KEY{,.pub} -> ~/.ssh/id_ed25519_sk_rk_alexis-perso{,.pub}"
          rm -rf "$SCRATCH_DIR"
          unset SCRATCH_DIR
          ok "Key saved as ~/.ssh/id_ed25519_sk_rk_alexis-perso (credential: rk-alexis-perso)"

          step "Adding key to agent"
          gum log --structured --level info "Touch the YubiKey when prompted."
          if ! ssh-add ~/.ssh/id_ed25519_sk_rk_alexis-perso 2>&1 | tee -a "$LOGFILE"; then
            fail "ssh-add failed. Check key permissions (chmod 600)."
          fi

          if ! ssh-add -l 2>&1 | tee -a "$LOGFILE"; then
            fail "SSH agent has no keys. Aborting."
          fi

          step "Cloning nixconf flake"
          gum log --structured --level info "Cloning via $SSH_AUTH_SOCK"
          if ! git clone git@github.com:Alexyz205/nixconf.git /root/nixconf 2>&1 | tee -a "$LOGFILE"; then
            gum log --structured --level error "git clone failed"
            gum log --structured --level debug "ssh-add -l output:"
            ssh-add -l >&2 || true
            fail "Could not clone nixconf. Auth failed (see logfile)."
          fi
          ok "Cloned to /root/nixconf"
          ls -la /root/nixconf >&2 || true

          ssh-agent -k
          ok "ssh-agent stopped"

          echo
          step "Confirming installation"
          gum style --foreground 212 --bold "Installation Summary"
          echo "  Host:   $HOST"
          echo "  Disk:   $DISK"
          echo "  Source: /root/nixconf#$HOST"
          echo

          gum confirm "Begin installation?" || fail "Aborted by user"

          step "Running disko-install (long)"
          gum spin --spinner globe --title "Installing NixOS... this will take a while" -- \
            disko-install \
              --flake "/root/nixconf#$HOST" \
              --disk main "$DISK" \
              --write-efi-boot-entries \
              --extra-files /root/nixconf /etc/nixos
          ok "disko-install completed"

          echo
          gum style \
            --foreground 2 --border-foreground 2 --border double \
            --align center --width 60 \
            "Installation complete."

          echo
          gum log --structured --level info "Remove the USB drive and reboot."
          gum log --structured --level info "Login as 'alexis' with your sops-managed password."
        '';
      in {
        nixpkgs.hostPlatform = "x86_64-linux";
        isoImage.edition = "custom-iso";

        services.openssh.enable = true;
        users.users.root = {
          initialHashedPassword = lib.mkForce null;
          password = "nixos";
        };

        programs.ssh.startAgent = true;

        environment.systemPackages = [
          pkgs.git
          pkgs.gum
          pkgs.yubikey-manager
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
