{ lib, ... }: {
  flake.modules.nixos.shell = { pkgs, ... }: {
    programs.zsh.enable = true;
    programs.git.enable = true;

    environment.systemPackages = with pkgs; [
      git
      curl
      wget
      openssl
      mise
    ];
  };
}