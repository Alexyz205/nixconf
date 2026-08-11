{
  inputs,
  lib,
  ...
}: {
  flake.nixosConfigurations.iso-server = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
      ({pkgs, ...}: {
        isoImage.edition = "server";

        environment.systemPackages = with pkgs; [
          ripgrep fd bat eza television fastfetch dust duf yq dasel jq tree-sitter
          delta diff-so-fancy glab gh devpod docker-compose podman-compose
          opencode fabric-ai pass age sops gnupg lazydocker lazyssh devenv
        ];

        boot.zfs.forceImportRoot = false;
        system.stateVersion = "24.11";
      })
    ];
  };
}
