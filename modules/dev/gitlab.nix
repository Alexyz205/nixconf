_:
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

  # Self-hosted instances whose git-over-https credentials glab resolves. The
  # matching PATs are exported by the sops module (see gitlabSecrets). Tokens
  # are per-host, so no global GITLAB_TOKEN is set (it would override every
  # host's stored credential in glab and gitlab.nvim).
  gitlabHosts = [
    "git.dxyz.pro"
    "gitlab.alexyz.org"
  ];

  credentialHelpers =
    pkgs:
    builtins.listToAttrs (
      map (host: {
        name = "https://${host}";
        value.helper = [
          ""
          "!${pkgs.glab}/bin/glab auth git-credential"
        ];
      }) gitlabHosts
    );

  gitlabSecrets = {
    GITLAB_DXYZ_TOKEN = { };
    GITLAB_ALEXYZ_TOKEN = { };
  };

  gitlabCfg =
    { pkgs }:
    {
      home.packages = [
        pkgs.glab
        # gitlab.nvim builds its bundled Go server on first use and caches it
        # under stdpath("data")/gitlab.nvim/bin, so the toolchain (>= 1.25.1)
        # is required.
        pkgs.go
      ];
      programs = {
        git.settings.credential = credentialHelpers pkgs;
        lazyvim.plugins.gitlab = gitlabLua;
        zsh.shellAliases = gitlabAliases;
      };
      sops.secrets = gitlabSecrets;
    };
in
{
  nixconf.modules.nixos.gitlab =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.gitlab.enable = lib.mkEnableOption "GitLab (glab, gitlab.nvim, per-host tokens)";
      config = lib.mkIf config.modules.gitlab.enable {
        environment.systemPackages = [
          pkgs.glab
          pkgs.go
        ];
        programs.git.config.credential = credentialHelpers pkgs;
        sops.secrets = gitlabSecrets;
        home-manager.users.${config.modules.users.userName} = gitlabCfg {
          inherit pkgs;
        };
      };
    };

  nixconf.modules.homeManager.gitlab =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.gitlab.enable = lib.mkEnableOption "GitLab (glab, gitlab.nvim, per-host tokens)";
      config = lib.mkIf config.modules.gitlab.enable (gitlabCfg {
        inherit pkgs;
      });
    };
}
