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
          step "Confirming installation"
          gum style --foreground 212 --bold "Installation Summary"
          echo "  Host:   $HOST"
          echo "  Disk:   $DISK"
          echo "  Source: $FLAKE_DIR#$HOST"
          echo

          gum confirm "Begin installation?" || fail "Aborted by user"

          step "Running disko-install (long)"
          gum spin --spinner globe --title "Installing NixOS... this will take a while" -- \
            disko-install \
              --flake "$FLAKE_DIR#$HOST" \
              --disk main "$DISK" \
              --write-efi-boot-entries \
              --extra-files "$FLAKE_DIR" /etc/nixos
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
        isoImage = {
          edition = "custom-iso";
          contents = [
            {
              source = self.sourceInfo.outPath;
              target = "/nixconf";
            }
          ];
        };

        services.openssh.enable = true;
        users.users.root = {
          initialHashedPassword = lib.mkForce null;
          password = "nixos";
        };

        environment.systemPackages = [
          pkgs.gum
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
