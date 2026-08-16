{
  inputs,
  lib,
  ...
}: let
  mkLazyvimCfg = {
    lazyvim,
    pkgs,
    autoFormatOnSave ? true,
  }: {
    imports = [lazyvim.homeManagerModules.default];
    programs.lazyvim = {
      enable = true;
      ignoreBuildNotifications = true;
      pluginSource = "nixpkgs";
      extras = {
        coding.mini-surround.enable = true;
        lang = {
          json.enable = true;
          markdown.enable = true;
          python.enable = true;
          toml.enable = true;
          yaml.enable = true;
        };
      };
      config = {
        options = ''
          local opt = vim.opt; local g = vim.g
          opt.number = true; opt.relativenumber = true
          opt.colorcolumn = "80"; opt.signcolumn = "yes"
          opt.scrolloff = 8; opt.termguicolors = true
          g.snacks_animate = false; opt.wrap = false
          opt.tabstop = 2; opt.softtabstop = 2; opt.shiftwidth = 2
          opt.expandtab = true; opt.smartindent = true
          opt.hlsearch = false; opt.incsearch = true
          opt.swapfile = false; opt.backup = false; opt.undofile = true
          opt.updatetime = 50; vim.opt.clipboard = "unnamedplus"
          vim.g.clipboard = "osc52"
          ${lib.optionalString (!autoFormatOnSave) "g.autoformat = false"}
        '';
        keymaps = ''
          local map = vim.keymap.set
          map("i", "<C-b>", "<ESC>^i", {}); map("i", "<C-e>", "<End>", {})
          map("i", "<C-h>", "<Left>", {}); map("i", "<C-l>", "<Right>", {})
          map("i", "<C-j>", "<Down>", {}); map("i", "<C-k>", "<Up>", {})
          map("n", "<C-s>", "<cmd>w<CR>", {}); map("n", "<C-S>", "<cmd>wa<CR>", {})
          map("n", "<C-c>", "<cmd>%y+<CR>", {})
          map("v", "J", ":m '>+1<CR>gv=gv", {}); map("v", "K", ":m '<-2<CR>gv=gv", {})
          map("n", "J", "mzJ`z", {}); map("n", "<C-d>", "<C-d>zz", {})
          map("n", "<C-u>", "<C-u>zz", {}); map("n", "n", "nzzzv", {})
          map("n", "N", "Nzzzv", {})
          map("x", "<leader>p", [["_dP]], {}); map({ "n", "v" }, "<leader>y", [["+y]], {})
          map("n", "<leader>Y", [["+Y]], {}); map({ "n", "v" }, "<leader>d", [["_d]], {})
          map("n", "<leader><leader>", "<cmd>so<CR>", {})
          map("n", "<C-h>", "<cmd>TmuxNavigateLeft<CR>", {})
          map("n", "<C-j>", "<cmd>TmuxNavigateDown<CR>", {})
          map("n", "<C-k>", "<cmd>TmuxNavigateUp<CR>", {})
          map("n", "<C-l>", "<cmd>TmuxNavigateRight<CR>", {})
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
      extraPackages = with pkgs; [
        marksman
        yaml-language-server
        vscode-json-languageserver
        basedpyright
        taplo
        ruff
        prettierd
        markdownlint-cli
      ];
    };
  };
in {
  flake.modules.nixos.lazyvim = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.lazyvim = {
      enable = lib.mkEnableOption "LazyVim";
      autoFormatOnSave = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Format buffer automatically on save.";
      };
    };
    config = lib.mkIf config.modules.lazyvim.enable {
      environment.systemPackages = with pkgs; [
        neovim
        marksman
        yaml-language-server
        vscode-json-languageserver
        basedpyright
        taplo
        ruff
        prettierd
        markdownlint-cli
      ];
      home-manager.users.${config.modules.users.userName} = mkLazyvimCfg {
        inherit (inputs) lazyvim;
        inherit pkgs;
        autoFormatOnSave = config.modules.lazyvim.autoFormatOnSave;
      };
    };
  };

  flake.modules.homeManager.lazyvim = {
    lazyvim,
    pkgs,
    ...
  }: mkLazyvimCfg {inherit lazyvim pkgs;};
}
