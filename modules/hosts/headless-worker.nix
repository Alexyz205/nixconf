{
  config,
  inputs,
  ...
}:
let
  system = "x86_64-linux";
  yubiPub = ../../config/ssh/id_ed25519_sk_rk_alexis-perso.pub;
  features = config.nixconf.nixosFeatures.server;
  mkBtrfsLayout = config.nixconf.mkBtrfsLayout;
  mkHostCommon = config.nixconf.mkHostCommon;

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
            modules = {
              # The server tier enables the base + server feature set (see
              # modules/flake/nixos.nix); only host-specific deltas live here.
              users.extraGroups = [
                "wheel"
                "podman"
              ];
              packages = {
                basic = true;
                security = true;
                devTools = true;
              };
            };
            users.users.${config.modules.users.userName}.openssh.authorizedKeys.keys = [
              (lib.trim (builtins.readFile yubiPub))
            ];

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
