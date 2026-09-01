-- ============================================================================
-- Snacks Picker defaults
-- ============================================================================
-- Show hidden files by default in the file and grep pickers (matching the tv
-- cable channels in config/television/cable/). Press `H` in the picker to
-- toggle hidden files on/off.
-- ============================================================================

return {
  "folke/snacks.nvim",
  opts = {
    input = { enabled = true },
    picker = {
      ui_select = true,
      sources = {
        files = { hidden = true },
        grep = { hidden = true },
      },
    },
  },
}
