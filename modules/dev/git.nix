{ lib, ... }:
let
  gitCfg = { pkgs, ... }: {
    enable = true;
    settings = {
      user = {
        name = "Alexyz205";
        email = "anathos205@gmail.com";
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
      url."git@github.com:".insteadOf = "gh:";
      url."git@git.dxyz.pro:".insteadOf = "gl:";
      credential."https://github.com".helper = [
        ""
        "!\${pkgs.gh}/bin/gh auth git-credential"
      ];
      credential."https://gist.github.com".helper = [
        ""
        "!\${pkgs.gh}/bin/gh auth git-credential"
      ];
    };
    includes = [
      {
        condition = "gitdir:~/repos/work/";
        path = "~/.config/git/config-work";
      }
    ];
  };

  gitAliases = {
    g = "git";
    ga = "git add";
    gc = "git commit";
    gcm = "git commit -m";
    gco = "git checkout";
    gd = "git diff";
    gl = "git log";
    gp = "git pull";
    gP = "git push";
    gs = "git status";
  };

  gitWorkConfig = {
    home.file.".config/git/config-work".text = ''
      [user]
        name = "Alexis Pigeon"
        email = "alexis.pigeon@take2games.com"
    '';
  };
in
{
  flake.modules.nixos.git =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.git.enable = lib.mkEnableOption "Git with delta, lazygit, gh";
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
        home-manager.users.${config.modules.users.userName} = gitWorkConfig // {
          programs.git = gitCfg { inherit pkgs; };
          programs.zsh.shellAliases = gitAliases;
        };
      };
    };

  flake.modules.homeManager.git =
    { pkgs, ... }:
    gitWorkConfig
    // {
      home.packages = with pkgs; [
        git
        delta
        gh
      ];
      programs.git = gitCfg { inherit pkgs; };
      programs.zsh.shellAliases = gitAliases;
    };
}
