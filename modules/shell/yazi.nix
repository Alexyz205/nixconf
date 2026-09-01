{ lib, ... }:
let
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
          fg = "#94e2d5";
        };
        find_keyword = {
          fg = "#f9e2af";
          bold = true;
          italic = true;
          underline = true;
        };
        find_position = {
          fg = "#f5c2e7";
          bg = "reset";
          bold = true;
          italic = true;
        };
        marker_copied = {
          fg = "#a6e3a1";
          bg = "#a6e3a1";
        };
        marker_cut = {
          fg = "#f38ba8";
          bg = "#f38ba8";
        };
        marker_marked = {
          fg = "#94e2d5";
          bg = "#94e2d5";
        };
        marker_selected = {
          fg = "#f9e2af";
          bg = "#f9e2af";
        };
        count_copied = {
          fg = "#1e1e2e";
          bg = "#a6e3a1";
        };
        count_cut = {
          fg = "#1e1e2e";
          bg = "#f38ba8";
        };
        count_selected = {
          fg = "#1e1e2e";
          bg = "#f9e2af";
        };
        border_symbol = "│";
        border_style = {
          fg = "#7f849c";
        };
      };
      tabs = {
        active = {
          fg = "#1e1e2e";
          bg = "#89b4fa";
          bold = true;
        };
        inactive = {
          fg = "#89b4fa";
          bg = "#313244";
        };
      };
      mode = {
        normal_main = {
          fg = "#1e1e2e";
          bg = "#89b4fa";
          bold = true;
        };
        normal_alt = {
          fg = "#89b4fa";
          bg = "#313244";
        };
        select_main = {
          fg = "#1e1e2e";
          bg = "#94e2d5";
          bold = true;
        };
        select_alt = {
          fg = "#94e2d5";
          bg = "#313244";
        };
        unset_main = {
          fg = "#1e1e2e";
          bg = "#f2cdcd";
          bold = true;
        };
        unset_alt = {
          fg = "#f2cdcd";
          bg = "#313244";
        };
      };
      status = {
        perm_sep = {
          fg = "#7f849c";
        };
        perm_type = {
          fg = "#89b4fa";
        };
        perm_read = {
          fg = "#f9e2af";
        };
        perm_write = {
          fg = "#f38ba8";
        };
        perm_exec = {
          fg = "#a6e3a1";
        };
        progress_label = {
          fg = "#ffffff";
          bold = true;
        };
        progress_normal = {
          fg = "#a6e3a1";
          bg = "#45475a";
        };
        progress_error = {
          fg = "#f9e2af";
          bg = "#f38ba8";
        };
      };
      pick = {
        border = {
          fg = "#89b4fa";
        };
        active = {
          fg = "#f5c2e7";
          bold = true;
        };
        inactive = { };
      };
      input = {
        border = {
          fg = "#89b4fa";
        };
        title = { };
        value = { };
        selected = {
          reversed = true;
        };
      };
      cmp.border = {
        fg = "#89b4fa";
      };
      tasks = {
        border = {
          fg = "#89b4fa";
        };
        title = { };
        hovered = {
          fg = "#f5c2e7";
          bold = true;
        };
      };
      which = {
        mask = {
          bg = "#313244";
        };
        cand = {
          fg = "#94e2d5";
        };
        rest = {
          fg = "#9399b2";
        };
        desc = {
          fg = "#f5c2e7";
        };
        separator = "  ";
        separator_style = {
          fg = "#585b70";
        };
      };
      help = {
        on = {
          fg = "#94e2d5";
        };
        run = {
          fg = "#f5c2e7";
        };
        hovered = {
          reversed = true;
          bold = true;
        };
        footer = {
          fg = "#313244";
          bg = "#cdd6f4";
        };
      };
      spot = {
        border = {
          fg = "#89b4fa";
        };
        title = {
          fg = "#89b4fa";
        };
        tbl_col = {
          fg = "#94e2d5";
        };
        tbl_cell = {
          fg = "#f5c2e7";
          bg = "#45475a";
        };
      };
      notify = {
        title_info = {
          fg = "#a6e3a1";
        };
        title_warn = {
          fg = "#f9e2af";
        };
        title_error = {
          fg = "#f38ba8";
        };
      };
      filetype.rules = [
        {
          mime = "image/*";
          fg = "#94e2d5";
        }
        {
          mime = "{audio,video}/*";
          fg = "#f9e2af";
        }
        {
          mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}";
          fg = "#f5c2e7";
        }
        {
          mime = "application/{pdf,doc,rtf}";
          fg = "#a6e3a1";
        }
        {
          mime = "vfs/{absent,stale}";
          fg = "#9399b2";
        }
        {
          url = "*";
          fg = "#cdd6f4";
        }
        {
          url = "*/";
          fg = "#89b4fa";
        }
      ];
      icon.dirs = [
        {
          name = ".config";
          text = "";
          fg = "#f5c2e7";
        }
        {
          name = ".git";
          text = "";
          fg = "#94e2d5";
        }
        {
          name = ".github";
          text = "";
          fg = "#89b4fa";
        }
        {
          name = ".npm";
          text = "";
          fg = "#89b4fa";
        }
        {
          name = "Desktop";
          text = "";
          fg = "#94e2d5";
        }
        {
          name = "Development";
          text = "";
          fg = "#94e2d5";
        }
        {
          name = "Documents";
          text = "";
          fg = "#94e2d5";
        }
        {
          name = "Downloads";
          text = "";
          fg = "#94e2d5";
        }
        {
          name = "Library";
          text = "";
          fg = "#94e2d5";
        }
        {
          name = "Movies";
          text = "";
          fg = "#94e2d5";
        }
        {
          name = "Music";
          text = "";
          fg = "#94e2d5";
        }
        {
          name = "Pictures";
          text = "";
          fg = "#94e2d5";
        }
        {
          name = "Public";
          text = "";
          fg = "#94e2d5";
        }
        {
          name = "Videos";
          text = "";
          fg = "#94e2d5";
        }
      ];
      icon.conds = [
        {
          "if" = "orphan";
          text = "";
          fg = "#cdd6f4";
        }
        {
          "if" = "link";
          text = "";
          fg = "#7f849c";
        }
        {
          "if" = "block";
          text = "";
          fg = "#f2cdcd";
        }
        {
          "if" = "char";
          text = "";
          fg = "#f2cdcd";
        }
        {
          "if" = "fifo";
          text = "";
          fg = "#f2cdcd";
        }
        {
          "if" = "sock";
          text = "";
          fg = "#f2cdcd";
        }
        {
          "if" = "sticky";
          text = "";
          fg = "#f2cdcd";
        }
        {
          "if" = "dummy";
          text = "";
          fg = "#f38ba8";
        }
        {
          "if" = "dir & hovered";
          text = "";
          fg = "#89b4fa";
        }
        {
          "if" = "dir";
          text = "";
          fg = "#89b4fa";
        }
        {
          "if" = "exec";
          text = "";
          fg = "#a6e3a1";
        }
        {
          "if" = "!dir";
          text = "";
          fg = "#cdd6f4";
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
      # view text with bat. `open`/`reveal` fall back to the defaults (xdg-open).
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
        fg = "#f38ba8";
      };
      staged = {
        fg = "#a6e3a1";
      };
      added = {
        fg = "#a6e3a1";
        bold = true;
      };
      deleted = {
        fg = "#f38ba8";
        bold = true;
      };
      updated = {
        fg = "#89b4fa";
      };
      untracked = {
        fg = "#f9e2af";
      };
      ignored = {
        fg = "#585b70";
      };
      clean = {
        fg = "#a6e3a1";
      };
      unknown = {
        fg = "#7f849c";
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
  flake.modules.nixos.yazi =
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

  flake.modules.homeManager.yazi =
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
