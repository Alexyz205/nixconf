{
  inputs,
  lib,
  ...
}: let
  lazyvimCfg = {
    lazyvim,
    pkgs,
    ...
  }: {
    imports = [lazyvim.homeManagerModules.default];
    programs.lazyvim = {
      enable = true;
      ignoreBuildNotifications = true;
      pluginSource = "nixpkgs";
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
      configFiles = toString ./config/lazyvim;
      extraPackages = with pkgs; [marksman yaml-language-server];
    };
  };
in {
  flake.modules.nixos.lazyvim = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.modules.lazyvim.enable = lib.mkEnableOption "LazyVim";
    config = lib.mkIf config.modules.lazyvim.enable {
      environment.systemPackages = with pkgs; [neovim marksman yaml-language-server];
      home-manager.users."alexis" = lazyvimCfg {
        inherit (inputs) lazyvim;
        inherit pkgs;
      };
    };
  };

  flake.modules.homeManager.lazyvim = lazyvimCfg;
}
