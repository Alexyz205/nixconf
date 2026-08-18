-- ============================================================================
-- tv.nvim - Television (tv) File & Grep Picker Integration
-- ============================================================================
-- Replaces LazyVim's snacks.nvim file/grep pickers with television (tv),
-- keeping the exact same keybindings and behavior -- only the backend
-- changes.
--
-- Backend: https://github.com/alexpasmantier/tv.nvim
-- TV binary: `television` package (see modules/dev/packages.nix)
--
-- Keybindings (unchanged from LazyVim):
--   <leader>ff / <leader>fF / <leader>fg / <leader><space> : Find Files (tv)
--   <leader>/  / <leader>sg  / <leader>sG                  : Grep (tv text)
--   <leader>sw / <leader>sW                                : Grep Word (tv text)
--   <leader>sB                                             : Grep Buffers (tv text)
--   <leader>t                                              : List all tv channels (remote control)
--
-- All other snacks pickers (buffers, recent, projects, LSP, ...) stay as-is.
-- ============================================================================

return {
  -- TV integration for Neovim
  {
    "alexpasmantier/tv.nvim",
    event = "VeryLazy",
    config = function()
      local h = require("tv").handlers

      require("tv").setup({
        global_keybindings = {
          channels = "<leader>t", -- open tv remote control (channel selector)
        },
        channels = {
          -- `files`: fuzzy find files in your project
          files = {
            handlers = {
              ["<CR>"] = h.open_as_files, -- default: open selected files
              ["<C-q>"] = h.send_to_quickfix, -- send to quickfix list
              ["<C-s>"] = h.open_in_split, -- open in horizontal split
              ["<C-v>"] = h.open_in_vsplit, -- open in vertical split
              ["<C-y>"] = h.copy_to_clipboard, -- copy paths to clipboard
            },
          },
          -- `text`: ripgrep search through file contents
          text = {
            handlers = {
              ["<CR>"] = h.open_at_line, -- jump to line:col in file
              ["<C-q>"] = h.send_to_quickfix, -- send matches to quickfix
              ["<C-s>"] = h.open_in_split, -- open in horizontal split
              ["<C-v>"] = h.open_in_vsplit, -- open in vertical split
              ["<C-y>"] = h.copy_to_clipboard, -- copy matches to clipboard
            },
          },
        },
      })
    end,
  },

  -- Route LazyVim's snacks file/grep keybindings to tv (same bindings, new backend)
  {
    "folke/snacks.nvim",
    keys = {
      -- find files
      { "<leader>ff", "<cmd>Tv files<cr>", desc = "Find Files (Root Dir)" },
      { "<leader>fF", "<cmd>Tv files<cr>", desc = "Find Files (cwd)" },
      { "<leader>fg", "<cmd>Tv files<cr>", desc = "Find Files (git-files)" },
      { "<leader><space>", "<cmd>Tv files<cr>", desc = "Find Files (Root Dir)" },
      -- grep
      { "<leader>/", "<cmd>Tv text<cr>", desc = "Grep (Root Dir)" },
      { "<leader>sg", "<cmd>Tv text<cr>", desc = "Grep (Root Dir)" },
      { "<leader>sG", "<cmd>Tv text<cr>", desc = "Grep (cwd)" },
      { "<leader>sw", "<cmd>Tv text @<C-r><C-w><cr>", desc = "Visual selection or word (Root Dir)", mode = { "n", "x" } },
      { "<leader>sW", "<cmd>Tv text @<C-r><C-w><cr>", desc = "Visual selection or word (cwd)", mode = { "n", "x" } },
      { "<leader>sB", "<cmd>Tv text<cr>", desc = "Grep Open Buffers" },
    },
  },
}
