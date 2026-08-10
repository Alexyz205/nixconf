# Shared module library (video: "Modularize NixOS and Home Manager").
#
# This file imports every module. Hosts (hosts/<host>/configuration.nix)
# only enable the modules they need via the `modules.<name>.enable` flag.
# Nothing here activates by itself: each module is inert until a host
# enables it.
{ ... }:

{
  imports = [
    ./boot.nix
    ./network.nix
    ./security.nix
    ./ssh.nix
    ./podman.nix
    ./nix.nix
    ./users.nix
    ./shell.nix
    ./packages.nix
    ./dotfiles.nix
    ./disko.nix
    ./secrets.nix
  ];
}
