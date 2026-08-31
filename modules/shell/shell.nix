{ lib, ... }:
let
  nixconf = "$HOME/repos/personal/nixconf";
  baseAliases = {
    nf = "cd $NIXCONF";
    repos = "cd $REPOS";
    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";
    mkdir = "mkdir -pv";
    f = "tv";
    p = "python";
    e = "exit";
    c = "clear";
  };
  nixAliases = {
    nc = "nix flake check $NIXCONF";
    ngc = "nix store gc";
    ngo = "nix store optimise";
    nu = "nix flake update $NIXCONF";
    nl = "nix flake lock $NIXCONF";
  };
  nixosAliases = {
    nr = "sudo nixos-rebuild switch --flake $NIXCONF";
    nrb = "nixos-rebuild build --flake $NIXCONF";
    nrt = "sudo nixos-rebuild test --flake $NIXCONF";
  };
  darwinAliases = {
    dr = "sudo darwin-rebuild switch --flake $NIXCONF";
    drb = "sudo darwin-rebuild build --flake $NIXCONF";
    drc = "sudo darwin-rebuild check --flake $NIXCONF";
  };
  hmAliases = {
    hm = "home-manager switch --flake $NIXCONF";
    hmb = "home-manager build --flake $NIXCONF";
    hmc = "home-manager build --flake $NIXCONF --check";
  };
  sharedFunctions = builtins.readFile ../../config/shell/functions.sh;
  zshExtra = builtins.readFile ../../config/shell/zsh-extra.zsh;

  mkShellCfg =
    extraAliases:
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      environmentVariables = {
        SHELL = "${pkgs.zsh}/bin/zsh";
        VISUAL = "nvim";
        EDITOR = "nvim";
        REPOS = "$HOME/repos";
        GITUSER = "alexyz205";
        GHREPOS = "$HOME/repos/github.com/alexyz205";
        NIXCONF = nixconf;
        EZA_CONFIG_DIR = "$XDG_CONFIG_HOME/eza";
        TMUX_AUTO_START = "1";
        BAT_THEME = "Catppuccin Mocha";
        PAGER = "bat";
        GIT_PAGER = "bat";
        LANG = "en_US.UTF-8";
      };
    in
    {
      programs.home-manager.enable = true;
      xdg.enable = true;
      home = {
        sessionPath = [
          "${config.home.homeDirectory}/bin"
          "${config.home.homeDirectory}/.local/bin"
        ];
      };
      home.sessionVariables = environmentVariables;
      home.file = {
        ".config/opencode/opencode.json".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/opencode/opencode.json";
        ".config/opencode/tui.json".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/opencode/tui.json";
        ".config/opencode/AGENTS.md".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/opencode/AGENTS.md";
        ".config/opencode/agents".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/opencode/agents";
        ".config/opencode/skills".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/opencode/skills";
        ".config/delta/catppuccin.gitconfig".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/delta/catppuccin.gitconfig";
        ".config/git/config-personal".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/git/config-personal";
        ".config/eza/theme.yml".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/eza/theme.yml";
      };
      programs.zsh = {
        enable = true;
        dotDir = config.home.homeDirectory;
        enableCompletion = true;
        defaultKeymap = "viins";
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
        history = {
          size = 100000;
          save = 100000;
          share = true;
        };
        shellAliases = extraAliases // {
          reload = "source ~/.zshrc";
        };
        initContent = lib.mkMerge [
          (lib.mkOrder 600 sharedFunctions)
          (lib.mkOrder 900 zshExtra)
        ];
      };
    };
in
{
  flake.modules.nixos.shell =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.shell.enable = lib.mkEnableOption "Shell (Zsh + env)";
      config = lib.mkIf config.modules.shell.enable {
        programs.zsh.enable = true;
        programs.git.enable = true;
        environment.systemPackages = with pkgs; [ git ];
        home-manager.users.${config.modules.users.userName} = mkShellCfg (
          baseAliases // nixAliases // nixosAliases
        );
      };
    };

  flake.modules.homeManager.shell =
    args@{ lib, pkgs, ... }:
    let
      aliases =
        baseAliases
        // nixAliases
        // hmAliases
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin darwinAliases;
    in
    mkShellCfg aliases args;
}
