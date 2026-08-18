{lib, ...}: let
  nixconf = "$HOME/repos/personal/nixconf";
  shellAliases = {
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
    nr = "sudo nixos-rebuild switch --flake $NIXCONF";
    nrb = "nixos-rebuild build --flake $NIXCONF";
    nrt = "sudo nixos-rebuild test --flake $NIXCONF";
    dr = "sudo darwin-rebuild switch --flake $NIXCONF";
    drb = "sudo darwin-rebuild build --flake $NIXCONF";
    drc = "sudo darwin-rebuild check --flake $NIXCONF";
    hm = "home-manager switch --flake $NIXCONF";
    hmb = "home-manager build --flake $NIXCONF";
    hmc = "home-manager build --flake $NIXCONF --check";
    nc = "nix flake check $NIXCONF";
    ngc = "nix store gc";
    ngo = "nix store optimise";
    nu = "nix flake update $NIXCONF";
    nl = "nix flake lock $NIXCONF";
    sec = "SOPS_AGE_KEY_FILE=$NIXCONF/config/sops/yubi-age-identity sops $NIXCONF/secrets/secrets.yaml";
  };
  sharedFunctions = builtins.readFile ../../config/shell/functions.sh;
  zshExtra = builtins.readFile ../../config/shell/zsh-extra.zsh;

  shellCfg = {
    pkgs,
    config,
    lib,
    ...
  }: let
    environmentVariables = {
      SHELL = "${pkgs.zsh}/bin/zsh";
      VISUAL = "nvim";
      EDITOR = "nvim";
      REPOS = "$HOME/repos";
      GITUSER = "alexyz205";
      GHREPOS = "$HOME/repos/github.com/alexyz205";
      NIXCONF = nixconf;
      XDG_CONFIG_HOME = "$HOME/.config";
      EZA_CONFIG_DIR = "$XDG_CONFIG_HOME/eza";
      TMUX_AUTO_START = "1";
      PASSWORD_STORE_DIR = "$HOME/.password-store";
      BAT_THEME = "Catppuccin Mocha";
      PAGER = "bat";
      GIT_PAGER = "bat";
      LANG = "en_US.UTF-8";
    };
    secretExports =
      let
        exportVar = name: secret:
          lib.optionalString (secret ? path) ''
            if [ -r "${secret.path}" ]; then
              export ${name}="$(cat "${secret.path}")"
            fi
          '';
      in
        builtins.concatStringsSep "" (lib.mapAttrsToList exportVar (config.sops.secrets or {}));
  in {
    programs.home-manager.enable = true;
    home = {
      sessionPath = ["${config.home.homeDirectory}/bin" "${config.home.homeDirectory}/.local/bin"];
    };
    home.sessionVariables = environmentVariables;
    home.file = {
      ".config/opencode/opencode.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/opencode/opencode.json";
      ".config/opencode/tui.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/opencode/tui.json";
      ".config/opencode/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/opencode/AGENTS.md";
      ".config/opencode/agents".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/opencode/agents";
      ".config/opencode/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/opencode/skills";
      ".config/television".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/television";
      ".config/delta/catppuccin.gitconfig".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/delta/catppuccin.gitconfig";
      ".config/git/config-personal".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/git/config-personal";
      ".config/eza/theme.yml".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/eza/theme.yml";
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
      shellAliases = shellAliases // {reload = "source ~/.zshrc";};
      initContent = lib.mkMerge [
        (lib.mkOrder 600 sharedFunctions)
        (lib.mkOrder 900 zshExtra)
        (lib.mkOrder 950 secretExports)
      ];
    };
  };
in {
  flake.modules.nixos.shell = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.shell.enable = lib.mkEnableOption "Shell (Zsh + env)";
    config = lib.mkIf config.modules.shell.enable {
      programs.zsh.enable = true;
      programs.git.enable = true;
      environment.systemPackages = with pkgs; [git];
      home-manager.users.${config.modules.users.userName} = shellCfg;
    };
  };

  flake.modules.homeManager.shell = shellCfg;
}