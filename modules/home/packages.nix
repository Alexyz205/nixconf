{
  pkgs,
  lib,
  ...
}:
{
  home.packages = with pkgs; [
    # File & text utilities
    ripgrep
    fd
    bat
    eza
    television
    fastfetch
    dust
    duf
    yq
    dasel
    jq
    tree-sitter

    # Version control
    delta
    diff-so-fancy
    glab
    gh

    # Containers & dev
    devpod
    docker-compose

    # Editors & AI
    opencode
    fabric-ai

    # Misc
    pass
    lazydocker
    lazyssh
    devenv
  ];
}
