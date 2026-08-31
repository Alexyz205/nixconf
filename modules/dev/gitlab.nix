{
  lib,
  ...
}:
let
  gitlabLua = builtins.readFile ../../config/gitlab/gitlab.lua;
  gitlabAliases = {
    gm = "glab mr";
    gml = "glab mr list";
    gmv = "glab mr view";
    gmc = "glab mr create";
    gma = "glab mr approve";
    gmm = "glab mr merge";
    gci = "glab ci";
    gcil = "glab ci list";
    gciv = "glab ci view";
  };

  gitlabCfg = { pkgs }: {
    home.packages = [
      pkgs.glab
      pkgs.go
    ];
    programs.git.settings.credential."https://git.dxyz.pro".helper = [
      ""
      "!\${pkgs.glab}/bin/glab auth git-credential"
    ];
    programs.lazyvim.plugins.gitlab = gitlabLua;
    programs.zsh.shellAliases = gitlabAliases;
    sops.secrets.GITLAB_TOKEN = { };
  };
in
{
  flake.modules.nixos.gitlab =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.gitlab.enable = lib.mkEnableOption "GitLab (glab, gitlab.nvim, GITLAB_TOKEN)";
      config = lib.mkIf config.modules.gitlab.enable {
        environment.systemPackages = [
          pkgs.glab
          pkgs.go
        ];
        programs.git.config.credential."https://git.dxyz.pro".helper = [
          ""
          "!\${pkgs.glab}/bin/glab auth git-credential"
        ];
        sops.secrets.GITLAB_TOKEN = { };
        home-manager.users.${config.modules.users.userName} = gitlabCfg { inherit pkgs; };
      };
    };

  flake.modules.homeManager.gitlab =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.gitlab.enable = lib.mkEnableOption "GitLab (glab, gitlab.nvim, GITLAB_TOKEN)";
      config = lib.mkIf config.modules.gitlab.enable (gitlabCfg {
        inherit pkgs;
      });
    };
}
