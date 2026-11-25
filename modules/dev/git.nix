{ lib, ... }:
let
  gitAliases = {
    g = "git";
    ga = "git add";
    gc = "git commit";
    gcm = "git commit -m";
    gco = "git checkout";
    gd = "git diff";
    gf = "git fetch --all --tags";
    gl = "git log";
    gp = "git pull";
    gP = "git push";
    gs = "git status";
  };

  gitOptions = {
    enable = lib.mkEnableOption "Git with delta, lazygit, gh";
    userName = lib.mkOption {
      type = lib.types.str;
      default = "Alexyz205";
      description = "Default committer name, used outside the work and personal directories.";
    };
    userEmail = lib.mkOption {
      type = lib.types.str;
      default = "anathos205@gmail.com";
      description = "Default committer email, used outside the work and personal directories.";
    };
    personalUserName = lib.mkOption {
      type = lib.types.str;
      default = "Alexyz205";
      description = "Committer name applied to repositories under personalDir.";
    };
    personalUserEmail = lib.mkOption {
      type = lib.types.str;
      default = "anathos205@gmail.com";
      description = "Committer email applied to repositories under personalDir.";
    };
    workUserName = lib.mkOption {
      type = lib.types.str;
      default = "Alexis Pigeon";
      description = "Committer name applied to repositories under workDir.";
    };
    workUserEmail = lib.mkOption {
      type = lib.types.str;
      default = "alexis.pigeon@take2games.com";
      description = "Committer email applied to repositories under workDir.";
    };
    workDir = lib.mkOption {
      type = lib.types.str;
      default = "~/repos/work/";
      description = "Directory whose repositories use the work identity. Keep the trailing slash.";
    };
    personalDir = lib.mkOption {
      type = lib.types.str;
      default = "~/repos/personal/";
      description = "Directory whose repositories use the personal identity. Keep the trailing slash.";
    };
  };

  # Credentials are intentionally not managed here: gh and glab authenticate
  # interactively (`gh auth login`, `glab auth login`) and keep the credential in
  # the OS keyring (or their own 0600 config when no keyring is available).
  # This module only wires the non-secret credential helpers and git identity.
  mkGitCfg =
    { cfg, pkgs }:
    {
      home.packages = with pkgs; [
        git
        delta
        gh
      ];
      programs.git = {
        enable = true;
        settings = {
          user = {
            name = cfg.userName;
            email = cfg.userEmail;
          };
          commit.verbose = true;
          core = {
            autocrlf = "input";
            compression = 9;
            whitespace = "error";
            preloadindex = true;
          };
          blame = {
            coloring = "highlightRecent";
            date = "relative";
          };
          diff = {
            context = 3;
            renames = "copies";
            interHunkContext = 10;
          };
          init.defaultBranch = "main";
          log = {
            abbrevCommit = true;
            graphColors = "blue,yellow,cyan,magenta,green,red";
          };
          status = {
            branch = true;
            short = true;
            showStash = true;
            showUntrackedFiles = "all";
          };
          pager = {
            branch = false;
            tag = false;
            diff = "delta";
          };
          delta = {
            features = "catppuccin-mocha";
            navigate = true;
            "side-by-side" = false;
          };
          include.path = "~/.config/delta/catppuccin.gitconfig";
          push = {
            autoSetupRemote = true;
            default = "current";
            followTags = true;
          };
          pull = {
            rebase = true;
            default = "current";
          };
          submodule.fetchJobs = 16;
          rebase = {
            autoStash = true;
            missingCommitsCheck = "warn";
          };
          transfer.fsckObjects = true;
          receive.fsckObjects = true;
          fetch.fsckObjects = true;
          branch.sort = "-committerdate";
          tag.sort = "-taggerdate";
          # Shortcuts resolve to HTTPS so gh/glab's credential helpers are used
          # instead of relying on a per-context SSH key.
          url."https://github.com/".insteadOf = "gh:";
          url."https://git.dxyz.pro/".insteadOf = "gl:";
          credential."https://github.com".helper = [
            ""
            "!${pkgs.gh}/bin/gh auth git-credential"
          ];
          credential."https://gist.github.com".helper = [
            ""
            "!${pkgs.gh}/bin/gh auth git-credential"
          ];
        };
        includes = [
          {
            condition = "gitdir:${cfg.personalDir}";
            path = "~/.config/git/config-personal";
          }
          {
            condition = "gitdir:${cfg.workDir}";
            path = "~/.config/git/config-work";
          }
        ];
      };
      home.file = {
        ".config/git/config-personal".text = ''
          [user]
            name = ${cfg.personalUserName}
            email = ${cfg.personalUserEmail}
        '';
        ".config/git/config-work".text = ''
          [user]
            name = ${cfg.workUserName}
            email = ${cfg.workUserEmail}
        '';
      };
      programs.zsh.shellAliases = gitAliases;
    };
in
{
  nixconf.modules.nixos.git =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.git = gitOptions;
      config = lib.mkIf config.modules.git.enable {
        environment.systemPackages = with pkgs; [
          git
          delta
          gh
        ];
        programs.git = {
          enable = true;
          config.init.defaultBranch = "main";
        };
        home-manager.users = lib.genAttrs config.modules.users.homeUsers (
          _:
          mkGitCfg {
            cfg = config.modules.git;
            inherit pkgs;
          }
        );
      };
    };

  nixconf.modules.homeManager.git =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.git = gitOptions;
      config = lib.mkIf config.modules.git.enable (mkGitCfg {
        cfg = config.modules.git;
        inherit pkgs;
      });
    };
}
