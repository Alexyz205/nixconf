-- ============================================================================
-- Vim-Tmux-Navigator Plugin Configuration
-- ============================================================================
-- Seamless navigation between Neovim splits and Tmux panes
-- Allows using same keybindings (C-h/j/k/l) for both contexts
-- ============================================================================
--
-- Requirements:
--   - Tmux must be configured with matching keybindings
--   - Add to ~/.tmux.conf:
--     is_vim="ps -o state= -o comm= -t '#{pane_tty}' | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"
--     bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h' 'select-pane -L'
--     bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j' 'select-pane -D'
--     bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k' 'select-pane -U'
--     bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l' 'select-pane -R'
--
-- See: https://github.com/christoomey/vim-tmux-navigator
-- ============================================================================

-- LazyVim's core keymaps bind <C-h/j/k/l> to window navigation. They are
-- applied on the `VeryLazy` event, which fires after this plugin's own
-- mappings, silently overriding them and breaking nvim -> tmux navigation.
-- Re-apply the navigator's mappings after `VeryLazy` so the plugin wins.
local navigator = {
  { "<C-h>", "TmuxNavigateLeft" },
  { "<C-j>", "TmuxNavigateDown" },
  { "<C-k>", "TmuxNavigateUp" },
  { "<C-l>", "TmuxNavigateRight" },
  { "<C-\\>", "TmuxNavigatePrevious" },
}

local function apply_navigator_mappings()
  for _, binding in ipairs(navigator) do
    vim.keymap.set("n", binding[1], ":<C-U>" .. binding[2] .. "<CR>", { silent = true })
  end
end

return {
  "christoomey/vim-tmux-navigator",
  lazy = false, -- Load immediately to ensure navigation works from start
  config = function()
    apply_navigator_mappings()
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      once = true,
      callback = apply_navigator_mappings,
    })
  end,
}