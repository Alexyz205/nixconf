{
  config,
  lib,
  ...
}:
let
  dotfiles = "${config.home.homeDirectory}/repos/personal/dotfiles";
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink path;
in
{
  home.file = {
    # opencode AI assistant config (bundles its own node_modules)
    ".config/opencode".source = mkSymlink "${dotfiles}/config/opencode";

    # Television config + cable channels
    ".config/television".source = mkSymlink "${dotfiles}/config/television";

    # Delta catppuccin theme (git includes reference this path)
    ".config/delta/catppuccin.gitconfig".source =
      mkSymlink "${dotfiles}/config/delta/catppuccin.gitconfig";

    # Git personal identity override (referenced by git includeIf)
    ".config/git/config-personal".source =
      mkSymlink "${dotfiles}/config/git/config-personal";

    # eza theme (read from $EZA_CONFIG_DIR/theme.yml)
    ".config/eza/theme.yml".source = mkSymlink "${dotfiles}/config/eza/theme.yml";
  };
}
