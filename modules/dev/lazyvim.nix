{
  inputs,
  lib,
  ...
}:
let
  lazyvimAliases = {
    v = "nvim";
  };
  lazyvimCfg =
    {
      pkgs,
      autoFormatOnSave ? true,
    }:
    {
      programs.zsh.shellAliases = lazyvimAliases;
      programs.lazyvim = {
        enable = true;
        ignoreBuildNotifications = true;
        pluginSource = "nixpkgs";
        # Extra tools made available to LazyVim/snacks: tectonic renders LaTeX
        # math and mermaid-cli renders Mermaid diagrams in markdown docs.
        extraPackages = with pkgs; [
          tectonic
          mermaid-cli
        ];
        extras = {
          coding.mini-surround.enable = true;
          util.dot.enable = true;
          util.octo.enable = true;
          editor.snacks-picker.enable = true;
          lang = {
            ansible.enable = true;
            clangd.enable = true;
            cmake.enable = true;
            docker.enable = true;
            git.enable = true;
            helm.enable = true;
            json.enable = true;
            markdown = {
              enable = true;
              config = ''
                return {
                  {
                    "stevearc/conform.nvim",
                    optional = true,
                    opts = {
                      formatters_by_ft = {
                        markdown = { "prettierd", "markdownlint-cli2" },
                        ["markdown.mdx"] = { "prettierd", "markdownlint-cli2" },
                      },
                    },
                  },
                }
              '';
            };
            nix.enable = true;
            python.enable = true;
            terraform.enable = true;
            toml.enable = true;
            yaml.enable = true;
          };
          ui = {
            # indent-blankline is configured in config/lazyvim/plugins/indent-blankline.lua
            indent-blankline.enable = true;
            treesitter-context.enable = true;
          };
        };
        config = {
          options = ''
            local opt = vim.opt
            local g = vim.g

            -- Editing comfort
            opt.number = true
            opt.relativenumber = true
            opt.colorcolumn = "80"
            opt.signcolumn = "yes"
            opt.scrolloff = 8
            opt.wrap = false
            opt.tabstop = 2
            opt.softtabstop = 2
            opt.shiftwidth = 2
            opt.expandtab = true
            opt.smartindent = true
            opt.hlsearch = false
            opt.incsearch = true
            opt.swapfile = false
            opt.backup = false
            opt.undofile = true
            opt.updatetime = 50
            opt.clipboard = "unnamedplus"
            opt.termguicolors = true

            g.snacks_animate = false
            g.lazyvim_python_lsp = "basedpyright"
            g.clipboard = "osc52"

            vim.filetype.add({ extension = { ino = "cpp" } })

            -- Disable lazy.nvim luarocks support: no installed plugin requires
            -- it, and it trips `checkhealth lazy` with a hererocks error.
            require("lazy.core.config").options.rocks.enabled = false
            ${lib.optionalString (!autoFormatOnSave) "g.autoformat = false"}
          '';
          keymaps = ''
            local map = vim.keymap.set

            -- Emacs-style cursor movement in insert mode
            map("i", "<C-b>", "<ESC>^i", {})
            map("i", "<C-e>", "<End>", {})
            map("i", "<C-h>", "<Left>", {})
            map("i", "<C-l>", "<Right>", {})
            map("i", "<C-j>", "<Down>", {})
            map("i", "<C-k>", "<Up>", {})

            -- Save (also in insert-ish contexts)
            map("n", "<C-s>", "<cmd>w<CR>", {})
            map("n", "<C-S>", "<cmd>wa<CR>", {})

            -- Yank whole buffer to clipboard
            map("n", "<C-c>", "<cmd>%y+<CR>", {})

            -- Keep cursor centered while navigating
            map("n", "<C-d>", "<C-d>zz", {})
            map("n", "<C-u>", "<C-u>zz", {})

            -- Move lines (visual) / join (normal), keep cursor put
            map("v", "J", ":m '>+1<CR>gv=gv", {})
            map("v", "K", ":m '<-2<CR>gv=gv", {})
            map("n", "J", "mzJ`z", {})

            -- Center search results
            map("n", "n", "nzzzv", {})
            map("n", "N", "Nzzzv", {})

            -- Clipboard: paste over selection without yanking, yank to system
            map("x", "<leader>p", [["_dP]], {})
            map({ "n", "v" }, "<leader>y", [["+y]], {})
            map("n", "<leader>Y", [["+Y]], {})
            map({ "n", "v" }, "<leader>d", [["_d]], {})

            -- Reload current file
            map("n", "<leader><leader>", "<cmd>so<CR>", {})

            -- NOTE: <C-h/j/k/l> tmux split navigation is provided by
            -- vim-tmux-navigator (see plugins/vim-tmux-navigator.lua); no need
            -- to remap here.
          '';
        };
        # LazyVim 16's default colorscheme loads tokyonight, so the theme must be
        # selected through `opts.colorscheme`. catppuccin is already declared by
        # LazyVim itself (name "catppuccin", lazy, default flavour mocha), so we
        # only need to load it on demand and then apply it.
        plugins.colorscheme = ''
          return {
            {
              "LazyVim/LazyVim",
              opts = {
                colorscheme = function()
                  require("lazy").load({ plugins = { "catppuccin" } })
                  vim.cmd.colorscheme("catppuccin")
                end,
              },
            },
          }
        '';
        configFiles = toString ../../config/lazyvim;
      };
    };
in
{
  flake.modules.nixos.lazyvim =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.lazyvim = {
        enable = lib.mkEnableOption "LazyVim";
        autoFormatOnSave = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Format buffer automatically on save.";
        };
      };
      config = lib.mkIf config.modules.lazyvim.enable {
        home-manager.users.${config.modules.users.userName} = {
          imports = [ inputs.lazyvim.homeManagerModules.default ];
        }
        // lazyvimCfg {
          inherit pkgs;
          autoFormatOnSave = config.modules.lazyvim.autoFormatOnSave;
        };
      };
    };

  flake.modules.homeManager.lazyvim =
    {
      config,
      lib,
      lazyvim,
      pkgs,
      ...
    }:
    {
      imports = [ lazyvim.homeManagerModules.default ];
      options.modules.lazyvim = {
        enable = lib.mkEnableOption "LazyVim";
        autoFormatOnSave = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Format buffer automatically on save.";
        };
      };
      config = lib.mkIf config.modules.lazyvim.enable (lazyvimCfg {
        inherit pkgs;
        autoFormatOnSave = config.modules.lazyvim.autoFormatOnSave;
      });
    };
}
