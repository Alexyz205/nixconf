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

  # Authentication is deliberately not managed by Nix: glab stores the host's
  # OAuth token (or PAT) in the OS keyring after one interactive login
  # (`glab auth login --hostname <host> --web`), falling back to its own 0600
  # config when no keyring is available. This keeps credentials out of the repo,
  # sops and the Nix store, and lets each machine authenticate only the hosts it
  # is allowed to use. Only the non-secret credential helpers are declared here.
  gitlabOptions = {
    enable = lib.mkEnableOption "GitLab (glab, gitlab.nvim, per-host login)";
    hosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "gitlab.alexyz.org"
      ];
      description = ''
        GitLab hosts for which the glab credential helper is wired into git.
        Authentication remains interactive per host; listing a host here does not
        grant access to it.
      '';
    };
  };

  credentialHelpers =
    pkgs: hosts:
    builtins.listToAttrs (
      map (host: {
        name = "https://${host}";
        value.helper = [
          ""
          "!${pkgs.glab}/bin/glab auth git-credential"
        ];
      }) hosts
    );

  mkGitlabCfg =
    { cfg, pkgs }:
    {
      home.packages = [
        pkgs.glab
        # gitlab.nvim builds its bundled Go server on first use and caches it
        # under stdpath("data")/gitlab.nvim/bin, so the toolchain (>= 1.25.1)
        # is required.
        pkgs.go
      ];
      programs = {
        git.settings.credential = credentialHelpers pkgs cfg.hosts;
        lazyvim.plugins.gitlab = gitlabLua;
        zsh.shellAliases = gitlabAliases;
      };
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
      options.modules.gitlab = gitlabOptions;
      config = lib.mkIf config.modules.gitlab.enable {
        environment.systemPackages = [
          pkgs.glab
          pkgs.go
        ];
        programs.git.config.credential = credentialHelpers pkgs config.modules.gitlab.hosts;
        home-manager.users = lib.genAttrs config.modules.users.homeUsers (
          _:
          mkGitlabCfg {
            cfg = config.modules.gitlab;
            inherit pkgs;
          }
        );
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
      options.modules.gitlab = gitlabOptions;
      config = lib.mkIf config.modules.gitlab.enable (mkGitlabCfg {
        cfg = config.modules.gitlab;
        inherit pkgs;
      });
    };
}
