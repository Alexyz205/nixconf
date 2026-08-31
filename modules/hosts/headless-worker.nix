{
  config,
  inputs,
  lib,
  ...
}:
let
  system = "x86_64-linux";
  yubiPub = ../../config/ssh/id_ed25519_sk_rk_alexis-perso.pub;
  features = config.flake.nixosFeatures.server;
  mkBtrfsLayout = config.flake.mkBtrfsLayout;
  mkHostCommon = config.flake.mkHostCommon;

  mkServer =
    {
      hostName,
      diskDevice ? "/dev/sda",
    }:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        { nixpkgs.hostPlatform = system; }
        inputs.disko.nixosModules.disko
        inputs.sops-nix.nixosModules.sops
        inputs.home-manager.nixosModules.home-manager
        (mkHostCommon {
          inherit hostName;
          stateVersion = "26.05";
        })
      ]
      ++ features
      ++ [
        (
          {
            config,
            pkgs,
            lib,
            ...
          }:
          {
            disko.devices.disk.main.device = diskDevice;
            disko.devices.disk.main.content = lib.mkForce {
              type = "gpt";
              partitions = {
                ESP = {
                  size = "1G";
                  type = "EF00";
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot";
                    mountOptions = [ "umask=0077" ];
                  };
                };
                root = {
                  size = "100%";
                  content = mkBtrfsLayout { };
                };
              };
            };

            # systemd-networkd instead of NetworkManager
            networking.networkmanager.enable = lib.mkForce false;
            networking.useNetworkd = true;
            systemd.network = {
              enable = true;
              networks."50-dhcp" = {
                matchConfig.Name = "en*";
                networkConfig.DHCP = "yes";
              };
            };
            services.resolved.enable = true;

            # SSH key from existing YubiKey pub (no hardware needed at runtime)
            modules.users.extraGroups = [
              "wheel"
              "podman"
            ];
            users.users.${config.modules.users.userName}.openssh.authorizedKeys.keys = [
              (lib.trim (builtins.readFile yubiPub))
            ];

            # Packages
            modules.packages = {
              basic = true;
              security = true;
              devTools = true;
            };
            modules.containers.enable = true;
            modules.shell.enable = true;
            modules.git.enable = true;
            modules.starship.enable = true;
            modules.tmux.enable = true;
            modules.bat.enable = true;
            modules.eza.enable = true;
            modules.lazygit.enable = true;
            modules.yazi.enable = true;
            modules.zoxide.enable = true;
            modules.lazyvim.enable = true;
            modules.tv.enable = true;
            modules.opencode.enable = true;

            # Server optimizations
            nix.gc = {
              automatic = true;
              dates = "weekly";
              options = "--delete-older-than 30d";
            };
            boot.kernelParams = [ "quiet" ];
          }
        )
      ];
    };
in
{
  flake.nixosConfigurations.headless-worker = mkServer {
    hostName = "headless-worker";
  };
}
