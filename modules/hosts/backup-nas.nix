{
  config,
  inputs,
  ...
}:
let
  system = "x86_64-linux";
  lib = inputs.nixpkgs.lib;
  yubiPub = ../../config/ssh/id_ed25519_sk_rk_alexis-perso.pub;
  resticPub = ../../config/ssh/restic-backup.pub;
  resticKeys = lib.optional (builtins.pathExists resticPub) (lib.trim (builtins.readFile resticPub));
  # Optional extra client key (phone SSH app, spare laptop). Add the single
  # public line to config/ssh/iphone.pub; absent file = no extra key.
  phonePub = ../../config/ssh/iphone.pub;
  phoneKeys = lib.optional (builtins.pathExists phonePub) (lib.trim (builtins.readFile phonePub));
  features = config.nixconf.nixosFeatures.base;
  mkBtrfsLayout = config.nixconf.mkBtrfsLayout;
  mkHostCommon = config.nixconf.mkHostCommon;

  mkNas =
    {
      hostName,
      diskDevice ? "/dev/nvme0n1",
    }:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        { nixpkgs.hostPlatform = system; }
        inputs.disko.nixosModules.disko
        inputs.home-manager.nixosModules.home-manager
        (mkHostCommon {
          inherit hostName;
          stateVersion = "26.05";
        })
        config.nixconf.modules.nixos.boot
        config.nixconf.modules.nixos.disko
        config.nixconf.modules.nixos.monitoring
        config.nixconf.modules.nixos.nas
        config.nixconf.modules.nixos.tailscale
      ]
      ++ features
      ++ [
        (
          {
            config,
            lib,
            pkgs,
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

            # DHCP on every interface; the router reserves 192.168.1.113.
            # Not matching "en*" avoids a no-network boot if the NIC enumerates
            # as eth0/eno1 on this test box.
            networking.networkmanager.enable = lib.mkForce false;
            networking.useNetworkd = true;
            networking.useDHCP = true;
            networking.hostId = "b4c9a7d2";
            services.resolved.enable = true;

            modules = {
              boot.enable = true;
              disko.enable = true;
              monitoring = {
                enable = true;
                # Listen on all interfaces but only open 9100 to the LAN via
                # modules.nas.exportNodeMetrics.
                expose = false;
              };
              nas = {
                enable = true;
                poolName = "tank";
                nfsClients = [
                  "192.168.1.0/24"
                  "10.244.0.0/16"
                ];
                resticAuthorizedKeys = resticKeys;
                ups.enable = true;
                media.enable = true;
              };
              # Out-of-band door into the LAN: this host advertises the whole
              # subnet, so tailnet clients reach Proxmox, the Talos VIP, PiHole
              # and Traefik without any of them running Tailscale.
              tailscale = {
                enable = true;
                advertiseRoutes = [ "192.168.1.0/24" ];
              };
              users.extraGroups = [ "wheel" ];
              packages = {
                basic = true;
                security = true;
                devTools = true;
              };
            };

            # Sender for Wake-on-LAN: the NAS is the always-on tailnet peer on
            # this LAN segment, so `ssh nas 'wakeonlan <mac>'` works remotely.
            environment.systemPackages = [ pkgs.wakeonlan ];

            services.prometheus.exporters.node = {
              listenAddress = lib.mkForce "0.0.0.0";
              enabledCollectors = lib.mkAfter [ "zfs" ];
            };

            # The zfs collector shells out to `zpool`; without it in the unit's
            # PATH it exports no zfs_pool_* series and logs nothing useful.
            systemd.services.prometheus-node-exporter.path = [ pkgs.zfs ];

            # Key-only root access: no password in the Nix store, no SSH
            # password authentication. The SSH key is the only way in.
            services.openssh.settings = {
              PermitRootLogin = lib.mkForce "prohibit-password";
              PasswordAuthentication = lib.mkForce false;
              KbdInteractiveAuthentication = lib.mkForce false;
            };
            # The first install came up without host keys; make the keygen unit
            # an explicit dependency instead of relying on ordering alone.
            systemd.services.sshd.wants = [ "sshd-keygen.service" ];
            systemd.services.sshd-keygen.wantedBy = [ "multi-user.target" ];
            users.users.root = {
              hashedPassword = "!";
              openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOBMQLDh11pxkVlW041VH9OmAYhpSwVwFu7vbOezQrIU alexis@workstation"
              ]
              ++ phoneKeys;
            };
            users.users.${config.modules.users.userName}.openssh.authorizedKeys.keys = [
              (lib.trim (builtins.readFile yubiPub))
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOBMQLDh11pxkVlW041VH9OmAYhpSwVwFu7vbOezQrIU alexis@workstation"
            ]
            ++ phoneKeys;

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
  flake.nixosConfigurations.backup-nas = mkNas {
    hostName = "backup-nas";
  };
}
