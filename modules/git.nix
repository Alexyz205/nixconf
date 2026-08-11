{ lib, ... }: {
  flake.modules.nixos.git = { config, lib, pkgs, ... }: {
    options.modules.git.enable = lib.mkEnableOption "Git with delta, lazygit, gh, glab";
    config = lib.mkIf config.modules.git.enable {
      environment.systemPackages = with pkgs; [ git delta diff-so-fancy gh glab lazygit ];
      programs.git = { enable = true; config.init.defaultBranch = "main"; };
      home-manager.users."alexis.pigeon".programs.git = {
        enable = true;
        settings = {
          user = { name = "Alexis Pigeon"; email = "alexis.pigeon@take2games.com"; };
          commit.verbose = true;
          core = { autocrlf = "input"; compression = 9; whitespace = "error"; preloadindex = true; };
          blame = { coloring = "highlightRecent"; date = "relative"; };
          diff = { context = 3; renames = "copies"; interHunkContext = 10; };
          init.defaultBranch = "main";
          log = { abbrevCommit = true; graphColors = "blue,yellow,cyan,magenta,green,red"; };
          status = { branch = true; short = true; showStash = true; showUntrackedFiles = "all"; };
          pager = { branch = false; tag = false; diff = "diff-so-fancy | \$PAGER"; };
          delta = { features = "catppuccin-mocha"; navigate = true; "side-by-side" = false; };
          include.path = "~/.config/delta/catppuccin.gitconfig";
          push = { autoSetupRemote = true; default = "current"; followTags = true; };
          pull = { rebase = true; default = "current"; };
          submodule.fetchJobs = 16;
          rebase = { autoStash = true; missingCommitsCheck = "warn"; };
          transfer.fsckObjects = true; receive.fsckObjects = true; fetch.fsckObjects = true;
          branch.sort = "-committerdate"; tag.sort = "-taggerdate";
          url."git@github.com:".insteadOf = "gh:"; url."git@git.dxyz.pro:".insteadOf = "gl:";
          credential."https://github.com".helper = [ "" "!\${pkgs.gh}/bin/gh auth git-credential" ];
          credential."https://gist.github.com".helper = [ "" "!\${pkgs.gh}/bin/gh auth git-credential" ];
          credential."https://git.dxyz.pro".helper = [ "" "!\${pkgs.glab}/bin/glab auth git-credential" ];
        };
        includes = [{ condition = "gitdir:~/repos/personal/"; path = "~/.config/git/config-personal"; }];
      };
    };
  };
}
