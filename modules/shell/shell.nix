_:
let
  palette = import ../../config/theme/catppuccin-mocha.nix;
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
  # The hm aliases must target the profile the shell actually runs in. Each
  # standalone profile sets modules.shell.hmProfile to its own flake key
  # (username@profile); only then are the aliases defined (a null hmProfile, as
  # on nix-darwin, means no hm alias).
  hmAliases = profile: {
    hm = "home-manager switch --flake $NIXCONF#${profile}";
    hmb = "home-manager build --flake $NIXCONF#${profile}";
    hmc = "home-manager build --flake $NIXCONF#${profile} --check";
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
      # eza's theme.yml uses upper-case hex; the palette stores lower-case.
      c = lib.toUpper;
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
      # Manage ~/.config/mimeapps.list so feature modules can set default
      # applications (browser => brave, images => swayimg, ...) declaratively.
      # Linux-only: the xdg.mimeApps module asserts non-darwin platforms.
      xdg.mimeApps.enable = pkgs.stdenv.hostPlatform.isLinux;
      home = {
        sessionPath = [
          # The home-manager profile bin (the generation ~/.nix-profile points
          # at): ensures every managed shell finds the tools without depending
          # on nix.sh (which no-ops when USER isn't exported, e.g. devpod exec).
          "${config.home.profileDirectory}/bin"
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
        ".config/delta/catppuccin.gitconfig".text = ''
          # Generated from config/theme/catppuccin-mocha.nix — do not edit by hand.
          [delta "catppuccin-mocha"]
            blame-palette = "${palette.base} ${palette.mantle} ${palette.crust} ${palette.surface0} ${palette.surface1}"
            commit-decoration-style = "${palette.overlay0} bold box ul"
            dark = true
            file-decoration-style = "${palette.overlay0}"
            file-style = "${palette.text}"
            hunk-header-decoration-style = "${palette.overlay0} box ul"
            hunk-header-file-style = bold
            hunk-header-line-number-style = bold "${palette.subtext0}"
            hunk-header-style = file line-number syntax
            line-numbers-left-style = "${palette.overlay0}"
            line-numbers-minus-style = bold "${palette.red}"
            line-numbers-plus-style = bold "${palette.green}"
            line-numbers-right-style = "${palette.overlay0}"
            line-numbers-zero-style = "${palette.overlay0}"
            minus-emph-style = bold syntax "#694559"
            minus-style = syntax "#493447"
            plus-emph-style = bold syntax "#4e6356"
            plus-style = syntax "#394545"
            map-styles = \
              bold purple => syntax "#5b4e74", \
              bold blue => syntax "#445375", \
              bold cyan => syntax "#446170", \
              bold yellow => syntax "#6b635b"
            syntax-theme = Catppuccin Mocha
        '';
        ".config/git/config-personal".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/nixconf/config/git/config-personal";
        ".config/eza/theme.yml".text = ''
          # Generated from config/theme/catppuccin-mocha.nix — do not edit by hand.
          colourful: true

          filekinds:
            normal: {foreground: "${c palette.subtext1}"}
            directory: {foreground: "${c palette.blue}"}
            symlink: {foreground: "${c palette.sky}"}
            pipe: {foreground: "${c palette.overlay1}"}
            block_device: {foreground: "${c palette.maroon}"}
            char_device: {foreground: "${c palette.maroon}"}
            socket: {foreground: "${c palette.surface2}"}
            special: {foreground: "${c palette.mauve}"}
            executable: {foreground: "${c palette.green}"}
            mount_point: {foreground: "${c palette.sapphire}"}

          perms:
            user_read: {foreground: "${c palette.text}"}
            user_write: {foreground: "${c palette.yellow}"}
            user_execute_file: {foreground: "${c palette.green}"}
            user_execute_other: {foreground: "${c palette.green}"}
            group_read: {foreground: "${c palette.subtext1}"}
            group_write: {foreground: "${c palette.yellow}"}
            group_execute: {foreground: "${c palette.green}"}
            other_read: {foreground: "${c palette.subtext0}"}
            other_write: {foreground: "${c palette.yellow}"}
            other_execute: {foreground: "${c palette.green}"}
            special_user_file: {foreground: "${c palette.mauve}"}
            special_other: {foreground: "${c palette.surface2}"}
            attribute: {foreground: "${c palette.subtext0}"}

          size:
            major: {foreground: "${c palette.subtext0}"}
            minor: {foreground: "${c palette.sky}"}
            number_byte: {foreground: "${c palette.text}"}
            number_kilo: {foreground: "${c palette.subtext1}"}
            number_mega: {foreground: "${c palette.blue}"}
            number_giga: {foreground: "${c palette.mauve}"}
            number_huge: {foreground: "${c palette.mauve}"}
            unit_byte: {foreground: "${c palette.subtext0}"}
            unit_kilo: {foreground: "${c palette.blue}"}
            unit_mega: {foreground: "${c palette.mauve}"}
            unit_giga: {foreground: "${c palette.mauve}"}
            unit_huge: {foreground: "${c palette.sapphire}"}

          users:
            user_you: {foreground: "${c palette.text}"}
            user_root: {foreground: "${c palette.red}"}
            user_other: {foreground: "${c palette.mauve}"}
            group_yours: {foreground: "${c palette.subtext1}"}
            group_other: {foreground: "${c palette.overlay1}"}
            group_root: {foreground: "${c palette.red}"}

          links:
            normal: {foreground: "${c palette.sky}"}
            multi_link_file: {foreground: "${c palette.sapphire}"}

          git:
            new: {foreground: "${c palette.green}"}
            modified: {foreground: "${c palette.yellow}"}
            deleted: {foreground: "${c palette.red}"}
            renamed: {foreground: "${c palette.teal}"}
            typechange: {foreground: "${c palette.pink}"}
            ignored: {foreground: "${c palette.overlay1}"}
            conflicted: {foreground: "${c palette.maroon}"}

          git_repo:
            branch_main: {foreground: "${c palette.text}"}
            branch_other: {foreground: "${c palette.mauve}"}
            git_clean: {foreground: "${c palette.green}"}
            git_dirty: {foreground: "${c palette.red}"}

          security_context:
            colon: {foreground: "${c palette.overlay1}"}
            user: {foreground: "${c palette.subtext1}"}
            role: {foreground: "${c palette.mauve}"}
            typ: {foreground: "${c palette.surface2}"}
            range: {foreground: "${c palette.mauve}"}

          file_type:
            image: {foreground: "${c palette.yellow}"}
            video: {foreground: "${c palette.red}"}
            music: {foreground: "${c palette.green}"}
            lossless: {foreground: "${c palette.teal}"}
            crypto: {foreground: "${c palette.surface2}"}
            document: {foreground: "${c palette.text}"}
            compressed: {foreground: "${c palette.pink}"}
            temp: {foreground: "${c palette.maroon}"}
            compiled: {foreground: "${c palette.sapphire}"}
            build: {foreground: "${c palette.surface2}"}
            source: {foreground: "${c palette.blue}"}

          punctuation: {foreground: "${c palette.overlay1}"}
          date: {foreground: "${c palette.yellow}"}
          inode: {foreground: "${c palette.subtext0}"}
          blocks: {foreground: "${c palette.overlay2}"}
          header: {foreground: "${c palette.text}"}
          octal: {foreground: "${c palette.teal}"}
          flags: {foreground: "${c palette.mauve}"}

          symlink_path: {foreground: "${c palette.sky}"}
          control_char: {foreground: "${c palette.sapphire}"}
          broken_symlink: {foreground: "${c palette.red}"}
          broken_path_overlay: {foreground: "${c palette.surface2}"}
        '';
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
        # devpod's ssh server inherits home-manager's __HM_*_SOURCED guards
        # from the agent env, which makes hm-session-vars.sh early-return and
        # leave PATH without the home-manager profile. Reset the guards in
        # .zshenv (runs for every zsh) and re-source the session variables.
        envExtra = ''
          unset __HM_SESS_VARS_SOURCED __HM_ZSH_SESS_VARS_SOURCED
          . "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh"
        '';
        initContent = lib.mkMerge [
          (lib.mkOrder 600 sharedFunctions)
          (lib.mkOrder 900 zshExtra)
        ];
      };
    };
in
{
  nixconf.modules.nixos.shell =
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
        # xdg.mimeApps takes ownership of mimeapps.list; desktops write their own
        # before nixconf does, so back the existing one up instead of failing.
        home-manager.backupFileExtension = "backup";
        # zsh is the managed shell: make it the login shell too. Otherwise tmux
        # (and anything that falls back to the passwd shell) spawns bash and
        # $SHELL stays wrong.
        users.users.${config.modules.users.userName}.shell = pkgs.zsh;
        environment.systemPackages = with pkgs; [ git ];
        home-manager.users.${config.modules.users.userName} = mkShellCfg (
          baseAliases // nixAliases // nixosAliases
        );
      };
    };

  nixconf.modules.homeManager.shell =
    args@{
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.shell = {
        enable = lib.mkEnableOption "Shell (Zsh + env)";
        hmProfile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Standalone home-manager profile key (username@profile) that the hm/hmb/hmc aliases switch/build against.";
        };
      };
      config = lib.mkIf config.modules.shell.enable (
        let
          aliases =
            baseAliases
            // nixAliases
            // lib.optionalAttrs (config.modules.shell.hmProfile != null) (
              hmAliases config.modules.shell.hmProfile
            )
            // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin darwinAliases;
        in
        lib.mkMerge [
          (mkShellCfg aliases args)
          {
            # Standalone home-manager cannot change the OS login shell (that
            # needs sudo + /etc/shells + chsh, deliberately out of scope for
            # HM), so on non-NixOS hosts the passwd shell stays bash and
            # tmux (or anything that falls back to the passwd/default shell)
            # spawns bash. Bridge it: an interactive bash exec's straight into zsh,
            # so every terminal and every restored tmux pane lands in zsh —
            # purely declaratively, no chsh/sudo. NixOS doesn't need this:
            # the shell module already sets users.users.<name>.shell = zsh.
            programs.bash = {
              enable = true;
              initExtra = lib.mkAfter ''
                if [[ -n $PS1 && -z $BASH_EXECUTION_STRING && -z $TMUX_IS_BASH_BRIDGED ]]; then
                  export TMUX_IS_BASH_BRIDGED=1
                  exec "${pkgs.zsh}/bin/zsh"
                fi
              '';
            };
          }
        ]
      );
    };
}
