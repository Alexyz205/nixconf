{lib, ...}: {
  flake.modules.nixos.nix = {...}: {
    nix.settings.allowed-users = ["@wheel"];
  };
}
