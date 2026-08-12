{
  inputs,
  lib,
  ...
}: let
  flakeSource = builtins.path {
    path = ../..;
    name = "nixconf-flake";
    filter = path: type:
      !(lib.lists.elem (builtins.baseNameOf path) [".git" "result"]);
  };
in {
  flake.nixosConfigurations.iso-workstation = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      { nixpkgs.hostPlatform = "x86_64-linux"; }
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
      ({pkgs, ...}: {
        isoImage.edition = "workstation";
        isoImage.contents = [
          {
            source = flakeSource;
            target = "/etc/nixos/flake";
          }
          {
            source = pkgs.writeTextFile {
              name = "install-workstation";
              executable = true;
              text = builtins.readFile ./../config/install-workstation.sh;
            };
            target = "/bin/install-workstation";
          }
        ];

        environment.systemPackages = with pkgs; [
          yubikey-manager
        ];

        boot.zfs.forceImportRoot = false;
        system.stateVersion = "24.11";
      })
    ];
  };
}