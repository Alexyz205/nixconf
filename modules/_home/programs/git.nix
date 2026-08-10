{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "Alexis Pigeon";
        email = "alexis.pigeon@take2games.com";
      };

      # Commit Settings
      commit.verbose = true;

      # Core Settings
      core = {
        autocrlf = "input";
        compression = 9;
        fsync = "none";
        whitespace = "error";
        preloadindex = true;
      };

      # Blame Configuration
      blame = {
        coloring = "highlightRecent";
        date = "relative";
      };

      # Diff Settings
      diff = {
        context = 3;
        renames = "copies";
        interHunkContext = 10;
      };

      # Repository Initialization
      init.defaultBranch = "main";

      # Log Configuration
      log = {
        abbrevCommit = true;
        graphColors = "blue,yellow,cyan,magenta,green,red";
      };

      # Status Display
      status = {
        branch = true;
        short = true;
        showStash = true;
        showUntrackedFiles = "all";
      };

      # Pager Configuration
      pager = {
        branch = false;
        tag = false;
        diff = "diff-so-fancy | $PAGER";
      };

      # Delta (diff viewer) Configuration
      delta = {
        features = "catppuccin-mocha";
        navigate = true;
        "side-by-side" = false;
      };

      # Delta catppuccin theme (symlinked file)
      include.path = "~/.config/delta/catppuccin.gitconfig";

      # Push Configuration
      push = {
        autoSetupRemote = true;
        default = "current";
        followTags = true;
      };

      # Pull Configuration
      pull = {
        rebase = true;
        default = "current";
      };

      # Submodule Settings
      submodule.fetchJobs = 16;

      # Rebase Configuration
      rebase = {
        autoStash = true;
        missingCommitsCheck = "warn";
      };

      # Integrity Settings
      transfer.fsckObjects = true;
      receive.fsckObjects = true;
      fetch.fsckObjects = true;

      # Sorting Settings
      branch.sort = "-committerdate";
      tag.sort = "-taggerdate";

      # Color Configuration
      color = {
        blame.highlightRecent = "black bold,1 year ago,white,1 month ago,default,7 days ago,blue";
        branch = {
          current = "magenta";
          local = "default";
          remote = "yellow";
          upstream = "green";
          plain = "blue";
        };
        diff = {
          meta = "black bold";
          frag = "magenta";
          context = "white";
          whitespace = "yellow reverse";
          old = "red";
        };
        decorate = {
          HEAD = "red";
          branch = "blue";
          tag = "yellow";
          remoteBranch = "magenta";
        };
      };

      # Interactive Settings
      interactive = {
        diffFilter = "diff-so-fancy --patch";
        singlekey = true;
      };

      # URL Shortcuts
      url."git@github.com:".insteadOf = "gh:";
      url."git@git.dxyz.pro:".insteadOf = "gl:";

      # Credential Helpers
      credential."https://github.com".helper = [
        ""
        "!${pkgs.gh}/bin/gh auth git-credential"
      ];
      credential."https://gist.github.com".helper = [
        ""
        "!${pkgs.gh}/bin/gh auth git-credential"
      ];
      credential."https://git.dxyz.pro".helper = [
        ""
        "!${pkgs.glab}/bin/glab auth git-credential"
      ];
    };

    includes = [
      {
        condition = "gitdir:~/repos/personal/";
        path = "~/.config/git/config-personal";
      }
    ];
  };
}
