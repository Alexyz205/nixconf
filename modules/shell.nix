{lib, ...}: let
  commonAliases = {
    dot = "cd $DOTFILES";
    repos = "cd $REPOS";
    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";
    mkdir = "mkdir -pv";
    ls = "eza --color=auto --icons=auto";
    la = "eza -la --icons=auto";
    ll = "eza -l --git --hyperlink --icons=auto";
    lt = "eza --tree --level=2 --icons=auto";
    lta = "eza --tree --level=2 --icons=auto -a";
    ltl = "eza --tree --level=2 --icons=auto -l";
    ldir = "eza --long --icons=auto --only-dirs";
    lg = "lazygit";
    lm = "eza --icons=auto --sort=modified";
    lz = "eza --icons=auto --sort=size";
    f = "tv";
    v = "nvim";
    t = "tmux new-session -A -s dev";
    p = "python";
    e = "exit";
    c = "clear";
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
    d = "docker";
    dc = "docker-compose";
    ld = "lazydocker";
    lss = "lazyssh";
    lssh = "lazyssh";
    dru = "docker run -it --rm -v ~/repos/personal/nixconf:/root/nixconf ubuntu bash";
    gm = "glab mr";
    gml = "glab mr list";
    gmv = "glab mr view";
    gmc = "glab mr create";
    gma = "glab mr approve";
    gmm = "glab mr merge";
    gci = "glab ci";
    gcil = "glab ci list";
    gciv = "glab ci view";
    ds = "devpod ssh";
    du = "devpod up .";
    pw = "pass";
    pwls = "pass ls";
    pwgen = "pass generate";
    pwcp = "pass show -c";
  };
  sharedFunctions = builtins.readFile ./config/shell/functions.sh;
  zshExtra = builtins.readFile ./config/shell/zsh-extra.zsh;
  bashExtra = builtins.readFile ./config/shell/bash-extra.sh;

  shellHm = {
    pkgs,
    config,
    lib,
    ...
  }: {
    programs.home-manager.enable = true;
    home = {
      sessionPath = ["${config.home.homeDirectory}/bin" "${config.home.homeDirectory}/.local/bin"];
    };
    home.sessionVariables = {
      SHELL = "${pkgs.zsh}/bin/zsh";
      VISUAL = "nvim";
      EDITOR = "nvim";
      REPOS = "$HOME/repos";
      GITUSER = "alexyz205";
      GHREPOS = "$HOME/repos/github.com/alexyz205";
      NICONF = "$HOME/repos/personal/nixconf";
      XDG_CONFIG_HOME = "$HOME/.config";
      EZA_CONFIG_DIR = "$XDG_CONFIG_HOME/eza";
      TMUX_AUTO_START = "1";
      PASSWORD_STORE_DIR = "$HOME/.password-store";
      BAT_THEME = "Catppuccin Mocha";
      PAGER = "bat";
      GIT_PAGER = "bat";
      LANG = "en_US.UTF-8";
    };
    nix = {
      package = pkgs.nix;
      settings = {
        experimental-features = ["nix-command" "flakes"];
        substituters = ["https://cache.nixos.org"];
        max-jobs = 8;
        cores = 0;
        connect-timeout = 0;
        keep-going = true;
        fallback = true;
        warn-dirty = false;
      };
    };
    home.file = {
      ".config/opencode".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/modules/config/opencode";
      ".config/television".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/modules/config/television";
      ".config/delta/catppuccin.gitconfig".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/modules/config/delta/catppuccin.gitconfig";
      ".config/git/config-personal".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/modules/config/git/config-personal";
      ".config/eza/theme.yml".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/modules/config/eza/theme.yml";
    };
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      defaultKeymap = "viins";
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      history = {
        size = 100000;
        save = 100000;
        share = true;
      };
      shellAliases = commonAliases // {reload = "source ~/.zshrc";};
      initContent = lib.mkMerge [
        (lib.mkOrder 600 sharedFunctions)
        (lib.mkOrder 900 zshExtra)
      ];
    };
    programs.bash = {
      enable = true;
      enableCompletion = true;
      historySize = 100000;
      shellAliases = commonAliases // {reload = "source ~/.bashrc";};
      initExtra = sharedFunctions + "\n" + bashExtra;
    };
  };
in {
  flake.modules.nixos.shell = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.shell.enable = lib.mkEnableOption "Shell (Zsh + Bash + env)";
    config = lib.mkIf config.modules.shell.enable {
      programs.zsh.enable = true;
      programs.git.enable = true;
      environment.systemPackages = with pkgs; [git];
      home-manager.users."alexis" = shellHm;
    };
  };

  flake.modules.homeManager.shell = shellHm;
}
