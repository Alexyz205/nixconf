{ lib, ... }:
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

  # Per-host PATs, keyed by the instance they authenticate. sops renders them
  # into glab's native credential store (~/.config/glab-cli/config.yml) rather
  # than exporting environment variables: no token leaks into child processes,
  # and glab keeps a separate credential per host (a GITLAB_TOKEN export would
  # override every host's stored token).
  gitlabTokens = {
    "git.dxyz.pro" = "GITLAB_DXYZ_TOKEN";
    "gitlab.alexyz.org" = "GITLAB_ALEXYZ_TOKEN";
  };

  gitlabHosts = builtins.attrNames gitlabTokens;

  gitlabSecrets = lib.genAttrs (builtins.attrValues gitlabTokens) (_: { });

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

  glabTemplates = hmConfig: {
    "glab-cli-config.yml" = {
      path = "${hmConfig.xdg.configHome}/glab-cli/config.yml";
      mode = "0600";
      content =
        "hosts:\n"
        + lib.concatStringsSep "" (
          lib.mapAttrsToList (
            host: var:
            "  ${host}:\n"
            + "    api_host: ${host}\n"
            + "    api_protocol: https\n"
            + "    git_protocol: https\n"
            + "    use_keyring: false\n"
            + "    token: ${hmConfig.sops.placeholder.${var}}\n"
          ) gitlabTokens
        );
    };
  };

  gitlabCfg =
    { pkgs, hmConfig }:
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
      sops.templates = glabTemplates hmConfig;
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
        home-manager.users.${config.modules.users.userName} =
          { config, ... }:
          gitlabCfg {
            inherit pkgs;
            hmConfig = config;
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
        hmConfig = config;
      });
    };
}
