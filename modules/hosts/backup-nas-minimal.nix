{
  config,
  inputs,
  ...
}:
let
  yubiPub = ../../config/ssh/id_ed25519_sk_rk_alexis-perso.pub;
  # Optional extra client key (phone SSH app, spare laptop). Add the single
  # public line to config/ssh/iphone.pub; absent file = no extra key.
  lib = inputs.nixpkgs.lib;
  phonePub = ../../config/ssh/iphone.pub;
  phoneKeys = lib.optional (builtins.pathExists phonePub) (lib.trim (builtins.readFile phonePub));
in
{
  flake.nixosConfigurations.backup-nas-minimal = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      inputs.disko.nixosModules.disko
      config.nixconf.modules.nixos.monitoring
      config.nixconf.modules.nixos.nas
      config.nixconf.modules.nixos.tailscale
      (
        { pkgs, lib, ... }:
        {
          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "26.05";

          networking.hostName = "backup-nas";
          networking.hostId = "b4c9a7d2";
          networking.useNetworkd = true;
          networking.useDHCP = true;
          # Keep DHCP for management (.5) and add the NAS address as an alias
          # (.113) so the switch does not cut the SSH session.
          systemd.network.networks."10-lan" = {
            matchConfig.MACAddress = "88:ae:dd:09:38:a9";
            address = [ "192.168.1.113/24" ];
          };
          services.resolved.enable = true;

          services.openssh = {
            enable = true;
            startWhenNeeded = false;
            settings = {
              PermitRootLogin = "prohibit-password";
              PasswordAuthentication = false;
              KbdInteractiveAuthentication = false;
            };
          };
          systemd.services.sshd.wants = [ "sshd-keygen.service" ];
          systemd.services.sshd-keygen.wantedBy = [ "multi-user.target" ];

          # Key-only root access: no password in the Nix store. mutableUsers
          # is false so activation overwrites the test password that is still
          # in /etc/shadow from the first install.
          users.mutableUsers = false;
          users.users.root = {
            hashedPassword = "!";
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOBMQLDh11pxkVlW041VH9OmAYhpSwVwFu7vbOezQrIU alexis@workstation"
              (lib.trim (builtins.readFile yubiPub))
            ]
            ++ phoneKeys;
          };
          users.users.alexis = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOBMQLDh11pxkVlW041VH9OmAYhpSwVwFu7vbOezQrIU alexis@workstation"
              (lib.trim (builtins.readFile yubiPub))
            ]
            ++ phoneKeys;
          };
          security.sudo.wheelNeedsPassword = false;

          networking.firewall = {
            enable = true;
            allowedTCPPorts = [ 22 ];
          };

          modules.nas = {
            enable = true;
            poolName = "tank";
            nfsClients = [
              "192.168.1.0/24"
              "10.244.0.0/16"
            ];
            resticAuthorizedKeys = lib.optional (builtins.pathExists ../../config/ssh/restic-backup.pub) (
              lib.trim (builtins.readFile ../../config/ssh/restic-backup.pub)
            );
            ups.enable = false;
            # Prometheus (in the k8s cluster) scrapes node_exporter on 9100;
            # modules.nas keeps the rule LAN-scoped.
            exportNodeMetrics = true;
          };

          modules.monitoring = {
            enable = true;
            # Bind 0.0.0.0 via the override below but leave expose = false so
            # the generic firewall opener stays off and only the
            # modules.nas LAN rule grants access.
            expose = false;
          };

          services.prometheus.exporters.node = {
            listenAddress = lib.mkForce "0.0.0.0";
            enabledCollectors = lib.mkAfter [ "zfs" ];
          };

          # Same role as the production NAS: subnet router for the LAN.
          modules.tailscale = {
            enable = true;
            advertiseRoutes = [ "192.168.1.0/24" ];
          };

          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;

          disko.devices.disk.main = {
            type = "disk";
            device = "/dev/nvme0n1";
            content = {
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
                  content = {
                    type = "filesystem";
                    format = "btrfs";
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                };
              };
            };
          };

          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];
          environment.systemPackages = [
            pkgs.zfs
            pkgs.curl
            pkgs.git
            pkgs.vim
          ];
        }
      )
    ];
  };
}
