{
  # Declarative partitioning for the installed system (used by disko).
  #
  # Scheme (security-focused best practice):
  #   GPT
  #   ├─ ESP (1G, vfat) -> /boot   unencrypted (UEFI must read it to boot)
  #   └─ LUKS2 (rest of disk, interactive passphrase at boot)
  #       └─ btrfs
  #          ├─ /root  -> /
  #          ├─ /nix   -> /nix
  #          ├─ /home  -> /home
  #          └─ /swap  -> swapfile (encrypted, lives inside LUKS)
  #
  # Everything except /boot is encrypted at rest.
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # CHANGE ME: target disk. Prefer /dev/disk/by-id/... over /dev/sdX
        # (by-id is stable across reboots, sdX names can change).
        device = "/dev/sda";
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
}
