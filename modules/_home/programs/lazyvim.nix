{
  config,
  pkgs,
  lib,
  lazyvim,
  ...
}:
{
  programs.lazyvim = {
    enable = true;
    ignoreBuildNotifications = true;

    # Prefer nixpkgs plugin versions (corporate SSL proxy breaks git source fetches)
    pluginSource = "nixpkgs";

    # LazyVim extras (mirrors the old lazyvim.json)
    extras = {
      coding.mini-surround.enable = true;
      dap.core.enable = true;
      editor.mini-files.enable = true;

      lang = {
        helm.enable = true;
        json.enable = true;
        markdown.enable = true;
        python.enable = true;
        toml.enable = true;
        yaml.enable = true;
      };
    };

    # Nix-declarative config (maps to lua/config/*.lua)
    config = {
      options = ''
        local opt = vim.opt
        local g = vim.g

        -- UI & display
        opt.number = true
        opt.relativenumber = true
        opt.colorcolumn = "80"
        opt.signcolumn = "yes"
        opt.scrolloff = 8
        opt.termguicolors = true
        g.snacks_animate = false -- Disable snacks animations for performance
        opt.wrap = false

        -- Indentation & formatting
        opt.tabstop = 2
        opt.softtabstop = 2
        opt.shiftwidth = 2
        opt.expandtab = true
        opt.smartindent = true

        -- Search
        opt.hlsearch = false
        opt.incsearch = true

        -- File handling
        opt.swapfile = false
        opt.backup = false
        opt.undofile = true
        opt.undodir = os.getenv("HOME") .. "/.vim/undodir"

        -- Performance & behavior
        opt.updatetime = 50
        opt.isfname:append("@-@")

        -- Clipboard (OSC 52 works over SSH/DevPod and in terminals)
        vim.opt.clipboard = "unnamedplus"
        vim.g.clipboard = "osc52"
      '';

      keymaps = ''
        local map = vim.keymap.set

        -- Insert mode emacs-style navigation
        map("i", "<C-b>", "<ESC>^i", { desc = "Move to beginning of line" })
        map("i", "<C-e>", "<End>", { desc = "Move to end of line" })
        map("i", "<C-h>", "<Left>", { desc = "Move left" })
        map("i", "<C-l>", "<Right>", { desc = "Move right" })
        map("i", "<C-j>", "<Down>", { desc = "Move down" })
        map("i", "<C-k>", "<Up>", { desc = "Move up" })

        -- File operations
        map("n", "<C-s>", "<cmd>w<CR>", { desc = "Save file" })
        map("n", "<C-S>", "<cmd>wa<CR>", { desc = "Save all files" })
        map("n", "<C-c>", "<cmd>%y+<CR>", { desc = "Copy whole file" })

        -- Visual mode line movement
        map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selected lines down" })
        map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selected lines up" })

        -- Substitute word under cursor
        map("n", "<leader>r", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], {
          desc = "Substitute word under cursor",
        })

        -- Scrolling/search with cursor centering
        map("n", "J", "mzJ`z", { desc = "Join lines keeping cursor position" })
        map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down and center" })
        map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up and center" })
        map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
        map("n", "N", "Nzzzv", { desc = "Previous search result (centered)" })

        -- Clipboard operations
        map("x", "<leader>p", [["_dP]], { desc = "Paste without yanking" })
        map({ "n", "v" }, "<leader>y", [["+y]], { desc = "Yank to system clipboard" })
        map("n", "<leader>Y", [["+Y]], { desc = "Yank line to system clipboard" })
        map({ "n", "v" }, "<leader>d", [["_d]], { desc = "Delete without yanking" })

        -- Source current file
        map("n", "<leader><leader>", "<cmd>so<CR>", { desc = "Source current file" })

        -- Tmux-aware window navigation (requires vim-tmux-navigator)
        map("n", "<C-h>", "<cmd>TmuxNavigateLeft<CR>", { desc = "Navigate left (Tmux aware)" })
        map("n", "<C-j>", "<cmd>TmuxNavigateDown<CR>", { desc = "Navigate down (Tmux aware)" })
        map("n", "<C-k>", "<cmd>TmuxNavigateUp<CR>", { desc = "Navigate up (Tmux aware)" })
        map("n", "<C-l>", "<cmd>TmuxNavigateRight<CR>", { desc = "Navigate right (Tmux aware)" })
      '';
    };

    # Colorscheme declared in Nix (via lazyConfig helper)
    plugins.colorscheme = lazyvim.lib.lazyConfig [
      {
        plugin = "catppuccin/nvim";
        lazy = true;
        name = "catppuccin";
        opts.flavour = "mocha";
      }
      {
        plugin = "LazyVim/LazyVim";
        opts.colorscheme = "catppuccin-mocha";
      }
    ];

    # Complex plugin configs stay as Lua files (mapped into ~/.config/nvim/lua/plugins/)
    configFiles = ../lazyvim;

    # LSP servers, formatters and tools for the enabled lang extras.
    # Mason is disabled by lazyvim-nix, so these must be provided via Nix.
    extraPackages = with pkgs; [
      marksman
      yaml-language-server
    ];
  };
}
