_args: {
  perSystem = {pkgs, ...}: let
    toolPkgs = with pkgs; [
      # shell
      zsh
      eza
      bat
      btop
      zoxide
      starship
      tmux
      yazi
      fzf

      # basic
      curl
      wget
      openssl
      ripgrep
      fd
      fastfetch
      dust
      duf
      yq
      jq
      tree-sitter

      # security
      age
      sops
      gnupg

      # dev tools
      git
      delta
      diff-so-fancy
      gh
      fabric-ai
      lazygit
      neovim
      opencode
      lazydocker
      devenv
      nixfmt-rfc-style
    ];
  in {
    packages.tools = pkgs.symlinkJoin {
      name = "nixconf-tools";
      paths = toolPkgs;
      meta.description = "Standalone dev tools from nixconf (install via nix profile install .#tools)";
    };
  };
}