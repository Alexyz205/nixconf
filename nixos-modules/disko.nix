# Disko module: declarative partitioning (LUKS2 + btrfs + swapfile).
# Enable with `modules.disko.enable = true`.
#
# This is a SHARED layout: hosts only override `modules.disko.device`.
#   GPT
#   ├─ ESP (1G, vfat) -> /boot   unencrypted (UEFI must read it to boot)
#   └─ LUKS2 (rest of disk, interactive passphrase at boot)
#       └─ btrfs
#          ├─ /root  -> /
#          ├─ /nix   -> /nix
#          ├─ /home  -> /home
#          └─ /swap  -> swapfile (encrypted, lives inside LUKS)
{ config, lib, ... }:

{
  options.modules.disko = {
    enable = lib.mkEnableOption "disko declarative partitioning";
    device = lib.mkOption {
      type = lib.types.str;
      default = "/dev/sda";
      description = "Target disk. Prefer /dev/disk/by-id/... over /dev/sdX";
    };
  };

  config = lib.mkIf config.modules.disko.enable {
    disko.devices = {
      disk = {
        main = {
          type = "disk";
          device = config.modules.disko.device;
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                size = "1G";
                type = "EF00"; # EFI System Partition
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "umask=0077" ];
                };
              };
              luks = {
                size = "100%";
                content = {
                  type = "luks";
                  name = "crypted";
                  # No keyFile => initrd asks for the passphrase interactively.
                  settings = {
                    allowDiscards = true; # TRIM support for SSDs
                  };
                  content = {
                    type = "btrfs";
                    extraArgs = [ "-f" ];
                    subvolumes = {
                      "/root" = {
                        mountpoint = "/";
                        mountOptions = [ "compress=zstd" "noatime" ];
                      };
                      "/home" = {
                        mountpoint = "/home";
                        mountOptions = [ "compress=zstd" "noatime" ];
                      };
                      "/nix" = {
                        mountpoint = "/nix";
                        mountOptions = [ "compress=zstd" "noatime" ];
                      };
                      "/swap" = {
                        mountpoint = "/.swapvol";
                        swap.swapfile.size = "8G";
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
