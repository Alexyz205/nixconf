{
  lib,
  ...
}: let
  extensions = [
    {id = "mnjggcdmjocbbbhaepohbliplgamfdfc";} # SponsorBlock
    {id = "eimadpbcbfnmbkopoojfekhnkhdbieeh";} # Dark Reader
    {id = "dbepggeogbaibhgnhhndojpepiihcmeb";} # Vimium
    {id = "bkkmolkhemgaeaeggcmfbghljjjoofoh";} # Catppuccin Mocha theme
  ];
in {
  flake.modules.nixos.brave = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.brave.enable = lib.mkEnableOption "Brave browser with Catppuccin Mocha theme";
    config = lib.mkIf config.modules.brave.enable {
      home-manager.users.${config.modules.users.userName} = {
        programs.brave = {
          enable = true;
          package = pkgs.brave;
          inherit extensions;
        };
      };
    };
  };

  flake.modules.homeManager.brave = {
    config,
    lib,
    pkgs,
    ...
  }: {
    programs.brave = {
      enable = true;
      package = pkgs.brave;
      inherit extensions;
    };
  };
}
