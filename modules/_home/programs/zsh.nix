{
  config,
  lib,
  pkgs,
  ...
}:
let
  commonAliases = import ../shell/aliases.nix;
  sharedFunctions = builtins.readFile ../shell/functions.sh;
  zshExtra = builtins.readFile ../shell/zsh-extra.zsh;
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    defaultKeymap = "viins";

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 100000;
      save = 100000;
      path = "${config.home.homeDirectory}/.zsh_history";
      share = true;
      expireDuplicatesFirst = true;
      ignoreDups = true;
      ignoreSpace = true;
      findNoDups = true;
    };

    setOptions = [ "HIST_VERIFY" ];

    shellAliases = commonAliases // {
      reload = "source ~/.zshrc";
    };

    initContent = lib.mkMerge [
      (lib.mkOrder 600 sharedFunctions)
      (lib.mkOrder 900 zshExtra)
    ];
  };
}
