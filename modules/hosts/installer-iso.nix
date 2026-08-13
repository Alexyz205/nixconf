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
          set -euo pipefail

          gum style \
            --foreground 212 --border-foreground 212 --border double \
            --align center --width 60 \
            "nixconf installer"

          echo

           HOST=$(gum choose --header "Which host to install?" headless-worker workstation)
          gum log --structured --level info "Selected host: $HOST"

          echo
          gum style --foreground 212 "Available disks:"
          DISK_INFO=$(lsblk -d -n -o NAME,SIZE,TYPE,MODEL 2>/dev/null | grep -v loop | grep -v ram || true)
          if [[ -z "$DISK_INFO" ]]; then
            gum log --structured --level error "No disks found"
            exit 1
          fi

          DISK_NAME=$(echo "$DISK_INFO" | gum choose --header "Select target disk:" | awk '{print $1}')
          DISK="/dev/$DISK_NAME"

          gum style --foreground 3 --bold "WARNING"
          gum style --foreground 3 "ALL DATA on $DISK will be DESTROYED."

          gum confirm "Are you sure?" || {
            gum log --structured --level error "Aborted by user"
            exit 1
          }

          echo
          gum style --foreground 212 "Checking YubiKey for SSH auth..."

          if ! ykman info &>/dev/null; then
            gum log --structured --level error "YubiKey not detected. Plug it in and retry."
            exit 1
          fi

          eval "$(ssh-agent -s)"
          gum spin --spinner dot --title "Unlocking YubiKey SSH key (touch when prompted)..." -- \
            ssh-add -t 300

          gum spin --spinner dot --title "Cloning nixconf flake (private repo)..." -- \
            git clone git@github.com:Alexyz205/nixconf.git /root/nixconf

          ssh-agent -k

          echo
          gum log --structured --level info "YubiKey detected."

          echo
          gum style --foreground 212 --bold "Installation Summary"
          echo "  Host:   $HOST"
          echo "  Disk:   $DISK"
          echo "  Source: /root/nixconf#$HOST"
          echo

          gum confirm "Begin installation?" || {
            gum log --structured --level error "Aborted by user"
            exit 1
          }

          gum spin --spinner globe --title "Installing NixOS... this will take a while" -- \
            disko-install \
              --flake "/root/nixconf#$HOST" \
              --disk main "$DISK" \
              --write-efi-boot-entries \
              --extra-files /root/nixconf /etc/nixos

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
        nix.settings.experimental-features = [ "nix-command" "flakes" ];

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
