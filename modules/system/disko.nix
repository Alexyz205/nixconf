{
  lib,
  ...
}:
let
  # Shared btrfs layout: the subvolume set every disko-managed host uses.
  # `luks = true` wraps it in a LUKS container (workstation); bare otherwise
  # (headless-worker). Exposed as config.flake.mkBtrfsLayout for hosts to reuse.
  btrfsLayout =
    {
      swapSize ? "8G",
      luks ? false,
      luksName ? "crypted",
    }:
    let
      fs = {
        type = "btrfs";
        extraArgs = [ "-f" ];
        subvolumes = {
          "/root" = {
            mountpoint = "/";
            mountOptions = [
              "compress=zstd"
              "noatime"
            ];
          };
          "/home" = {
            mountpoint = "/home";
            mountOptions = [
              "compress=zstd"
              "noatime"
            ];
          };
          "/nix" = {
            mountpoint = "/nix";
            mountOptions = [
              "compress=zstd"
              "noatime"
            ];
          };
          "/swap" = {
            mountpoint = "/.swapvol";
            swap.swapfile.size = swapSize;
          };
        };
      };
    in
    if luks then
      {
        type = "luks";
        name = luksName;
        settings.allowDiscards = true;
        content = fs;
      }
    else
      fs;
in
{
  flake.mkBtrfsLayout = btrfsLayout;

  flake.modules.nixos.disko =
    {
      config,
      lib,
      ...
    }:
    {
      options.modules.disko.enable = lib.mkEnableOption "Disko disk layout";
      config = lib.mkIf config.modules.disko.enable {
        disko.devices.disk.main = {
          type = "disk";
          device = lib.mkDefault "/dev/sda";
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
              luks = {
                size = "100%";
                content = btrfsLayout { luks = true; };
              };
            };
          };
        };
      };
    };
}
