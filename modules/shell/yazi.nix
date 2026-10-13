{ lib, ... }:
let
  palette = import ../../config/theme/catppuccin-mocha.nix;
  yaziCfg = {
    enable = true;
    shellWrapperName = "y";
    enableZshIntegration = true;

    settings = {
      mgr = {
        show_hidden = true;
      };
    };

    theme = {
      mgr = {
        cwd = {
          fg = "${palette.teal}";
        };
        find_keyword = {
          fg = "${palette.yellow}";
          bold = true;
          italic = true;
          underline = true;
        };
        find_position = {
          fg = "${palette.pink}";
          bg = "reset";
          bold = true;
          italic = true;
        };
        marker_copied = {
          fg = "${palette.green}";
          bg = "${palette.green}";
        };
        marker_cut = {
          fg = "${palette.red}";
          bg = "${palette.red}";
        };
        marker_marked = {
          fg = "${palette.teal}";
          bg = "${palette.teal}";
        };
        marker_selected = {
          fg = "${palette.yellow}";
          bg = "${palette.yellow}";
        };
        count_copied = {
          fg = "${palette.base}";
          bg = "${palette.green}";
        };
        count_cut = {
          fg = "${palette.base}";
          bg = "${palette.red}";
        };
        count_selected = {
          fg = "${palette.base}";
          bg = "${palette.yellow}";
        };
        border_symbol = "│";
        border_style = {
          fg = "${palette.overlay1}";
        };
      };
      tabs = {
        active = {
          fg = "${palette.base}";
          bg = "${palette.blue}";
          bold = true;
        };
        inactive = {
          fg = "${palette.blue}";
          bg = "${palette.surface0}";
        };
      };
      mode = {
        normal_main = {
          fg = "${palette.base}";
          bg = "${palette.blue}";
          bold = true;
        };
        normal_alt = {
          fg = "${palette.blue}";
          bg = "${palette.surface0}";
        };
        select_main = {
          fg = "${palette.base}";
          bg = "${palette.teal}";
          bold = true;
        };
        select_alt = {
          fg = "${palette.teal}";
          bg = "${palette.surface0}";
        };
        unset_main = {
          fg = "${palette.base}";
          bg = "${palette.flamingo}";
          bold = true;
        };
        unset_alt = {
          fg = "${palette.flamingo}";
          bg = "${palette.surface0}";
        };
      };
      status = {
        perm_sep = {
          fg = "${palette.overlay1}";
        };
        perm_type = {
          fg = "${palette.blue}";
        };
        perm_read = {
          fg = "${palette.yellow}";
        };
        perm_write = {
          fg = "${palette.red}";
        };
        perm_exec = {
          fg = "${palette.green}";
        };
        progress_label = {
          fg = "#ffffff";
          bold = true;
        };
        progress_normal = {
          fg = "${palette.green}";
          bg = "${palette.surface1}";
        };
        progress_error = {
          fg = "${palette.yellow}";
          bg = "${palette.red}";
        };
      };
      pick = {
        border = {
          fg = "${palette.blue}";
        };
        active = {
          fg = "${palette.pink}";
          bold = true;
        };
        inactive = { };
      };
      input = {
        border = {
          fg = "${palette.blue}";
        };
        title = { };
        value = { };
        selected = {
          reversed = true;
        };
      };
      cmp.border = {
        fg = "${palette.blue}";
      };
      tasks = {
        border = {
          fg = "${palette.blue}";
        };
        title = { };
        hovered = {
          fg = "${palette.pink}";
          bold = true;
        };
      };
      which = {
        mask = {
          bg = "${palette.surface0}";
        };
        cand = {
          fg = "${palette.teal}";
        };
        rest = {
          fg = "${palette.overlay2}";
        };
        desc = {
          fg = "${palette.pink}";
        };
        separator = "  ";
        separator_style = {
          fg = "${palette.surface2}";
        };
      };
      help = {
        on = {
          fg = "${palette.teal}";
        };
        run = {
          fg = "${palette.pink}";
        };
        hovered = {
          reversed = true;
          bold = true;
        };
        footer = {
          fg = "${palette.surface0}";
          bg = "${palette.text}";
        };
      };
      spot = {
        border = {
          fg = "${palette.blue}";
        };
        title = {
          fg = "${palette.blue}";
        };
        tbl_col = {
          fg = "${palette.teal}";
        };
        tbl_cell = {
          fg = "${palette.pink}";
          bg = "${palette.surface1}";
        };
      };
      notify = {
        title_info = {
          fg = "${palette.green}";
        };
        title_warn = {
          fg = "${palette.yellow}";
        };
        title_error = {
          fg = "${palette.red}";
        };
      };
      filetype.rules = [
        {
          mime = "image/*";
          fg = "${palette.teal}";
        }
        {
          mime = "{audio,video}/*";
          fg = "${palette.yellow}";
        }
        {
          mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}";
          fg = "${palette.pink}";
        }
        {
          mime = "application/{pdf,doc,rtf}";
          fg = "${palette.green}";
        }
        {
          mime = "vfs/{absent,stale}";
          fg = "${palette.overlay2}";
        }
        {
          url = "*";
          fg = "${palette.text}";
        }
        {
          url = "*/";
          fg = "${palette.blue}";
        }
      ];
      icon.dirs = [
        {
          name = ".config";
          text = "";
          fg = "${palette.pink}";
        }
        {
          name = ".git";
          text = "";
          fg = "${palette.teal}";
        }
        {
          name = ".github";
          text = "";
          fg = "${palette.blue}";
        }
        {
          name = ".npm";
          text = "";
          fg = "${palette.blue}";
        }
        {
          name = "Desktop";
          text = "";
          fg = "${palette.teal}";
        }
        {
          name = "Development";
          text = "";
          fg = "${palette.teal}";
        }
        {
          name = "Documents";
          text = "";
          fg = "${palette.teal}";
        }
        {
          name = "Downloads";
          text = "";
          fg = "${palette.teal}";
        }
        {
          name = "Library";
          text = "";
          fg = "${palette.teal}";
        }
        {
          name = "Movies";
          text = "";
          fg = "${palette.teal}";
        }
        {
          name = "Music";
          text = "";
          fg = "${palette.teal}";
        }
        {
          name = "Pictures";
          text = "";
          fg = "${palette.teal}";
        }
        {
          name = "Public";
          text = "";
          fg = "${palette.teal}";
        }
        {
          name = "Videos";
          text = "";
          fg = "${palette.teal}";
        }
      ];
      icon.conds = [
        {
          "if" = "orphan";
          text = "";
          fg = "${palette.text}";
        }
        {
          "if" = "link";
          text = "";
          fg = "${palette.overlay1}";
        }
        {
          "if" = "block";
          text = "";
          fg = "${palette.flamingo}";
        }
        {
          "if" = "char";
          text = "";
          fg = "${palette.flamingo}";
        }
        {
          "if" = "fifo";
          text = "";
          fg = "${palette.flamingo}";
        }
        {
          "if" = "sock";
          text = "";
          fg = "${palette.flamingo}";
        }
        {
          "if" = "sticky";
          text = "";
          fg = "${palette.flamingo}";
        }
        {
          "if" = "dummy";
          text = "";
          fg = "${palette.red}";
        }
        {
          "if" = "dir & hovered";
          text = "";
          fg = "${palette.blue}";
        }
        {
          "if" = "dir";
          text = "";
          fg = "${palette.blue}";
        }
        {
          "if" = "exec";
          text = "";
          fg = "${palette.green}";
        }
        {
          "if" = "!dir";
          text = "";
          fg = "${palette.text}";
        }
      ];
    };
  };

  # Dynamic parts: the git + mount plugins and their keymaps. Kept separate so
  # `yaziCfg` above stays a static, format-friendly base.
  mkYaziCfg = { pkgs }: {
    # Tools referenced by the custom openers below, guaranteed on the yazi
    # wrapper's PATH.
    extraPackages = [
      pkgs.bat
    ]
    # swayimg: the image/* opener (swayimg is Wayland-only, hence Linux-gated).
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      pkgs.swayimg
    ]
    # mount.yazi needs udisksctl/lsblk/eject (Linux) to mount disks.
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      pkgs.udisks2
      pkgs.util-linux
      pkgs.glib.bin
    ];

    plugins = {
      git = {
        package = pkgs.yaziPlugins.git;
        setup = true;
        settings.order = 1500;
      };
      mount = pkgs.yaziPlugins.mount;
      # bat-powered text previewer (replaces the built-in syntect `code`).
      bat = ../../config/yazi/bat.yazi;
    };

    settings = {
      # Show human-readable file sizes in the file list.
      mgr.linemode = "size";

      # Openers backed by the user's own tooling: edit with nvim (LazyVim),
      # view text with bat, open images with swayimg. `open`/`reveal` fall back
      # to the defaults (xdg-open) for everything else.
      opener = {
        edit = [
          {
            run = "nvim %s";
            desc = "Edit with nvim";
            for = "unix";
            block = true;
          }
        ];
        view = [
          {
            run = "bat --color=always --paging=never %s";
            desc = "View with bat";
            for = "unix";
            block = true;
          }
        ];
        swayimg = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          {
            run = "swayimg %s";
            desc = "Open with swayimg";
            for = "unix";
            block = true;
          }
        ];
      };

      # Prepend (not replace) so default open rules still apply for other types.
      open.prepend_rules = [
        {
          mime = "text/*";
          use = [
            "edit"
            "view"
          ];
        }
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        {
          mime = "image/*";
          use = [ "swayimg" ];
        }
      ];

      plugin.prepend_fetchers = [
        {
          url = "*";
          run = "git";
          group = "git";
        }
        {
          url = "*/";
          run = "git";
          group = "git";
        }
      ];

      # Preview text files with the bat plugin instead of yazi's built-in `code`
      # highlighter. Prepend so the bat rule wins over the default text/* rule.
      plugin.prepend_previewers = [
        {
          mime = "text/*";
          run = "bat";
        }
        {
          mime = "application/{json,ndjson,javascript,wine-extension-ini}";
          run = "bat";
        }
      ];
    };

    # mount.yazi: `M` opens a disk mount manager (udisksctl on Linux).
    keymap.mgr.prepend_keymap = [
      {
        on = "M";
        run = "plugin mount";
        desc = "Manage mounted disks";
      }
    ];

    theme.git = {
      unstaged = {
        fg = "${palette.red}";
      };
      staged = {
        fg = "${palette.green}";
      };
      added = {
        fg = "${palette.green}";
        bold = true;
      };
      deleted = {
        fg = "${palette.red}";
        bold = true;
      };
      updated = {
        fg = "${palette.blue}";
      };
      untracked = {
        fg = "${palette.yellow}";
      };
      ignored = {
        fg = "${palette.surface2}";
      };
      clean = {
        fg = "${palette.green}";
      };
      unknown = {
        fg = "${palette.overlay1}";
      };
      unstaged_sign = "M";
      staged_sign = "A";
      added_sign = "A";
      deleted_sign = "D";
      updated_sign = "U";
      untracked_sign = "?";
      ignored_sign = "!";
      clean_sign = " ";
      unknown_sign = "?";
    };
  };
in
{
  nixconf.modules.nixos.yazi =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.yazi.enable = lib.mkEnableOption "Yazi (terminal file manager)";
      config = lib.mkIf config.modules.yazi.enable {
        home-manager.users.${config.modules.users.userName} = {
          programs.yazi = lib.recursiveUpdate yaziCfg (mkYaziCfg {
            inherit pkgs;
          });
          programs.zsh.shellAliases.ygr = "y \"$(git rev-parse --show-toplevel 2>/dev/null)\"";
        }
        // lib.optionalAttrs (config ? stylix) {
          stylix.targets.yazi.enable = false;
        };
      };
    };

  nixconf.modules.homeManager.yazi =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.yazi.enable = lib.mkEnableOption "Yazi (terminal file manager)";
      config = lib.mkIf config.modules.yazi.enable {
        programs.yazi = lib.recursiveUpdate yaziCfg (mkYaziCfg {
          inherit pkgs;
        });
        programs.zsh.shellAliases.ygr = "y \"$(git rev-parse --show-toplevel 2>/dev/null)\"";
      };
    };
}
