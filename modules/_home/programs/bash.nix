{
  config,
  lib,
  pkgs,
  ...
}:
let
  commonAliases = import ../shell/aliases.nix;
  sharedFunctions = builtins.readFile ../shell/functions.sh;
  bashExtra = builtins.readFile ../shell/bash-extra.sh;
in
{
  programs.bash = {
    enable = true;
    enableCompletion = true;

    historySize = 100000;
    historyFileSize = 100000;
    historyFile = "~/.bash_history";
    historyControl = [
      "ignoreboth"
      "erasedups"
    ];
    historyIgnore = [
      "&"
      "ls"
      "cd"
      "cd -"
      "pwd"
      "exit"
      "date"
      "* --help"
    ];

    shellAliases = commonAliases // {
      reload = "source ~/.bashrc";
    };

    initExtra = sharedFunctions + "\n" + bashExtra;
  };
}
