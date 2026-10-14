return {
	"christoomey/vim-tmux-navigator",
	lazy = false,
	init = function()
		-- LazyVim binds <C-h/j/k/l> on the VeryLazy event, which fires after the
		-- plugin's own mappings. Disable them here and rebind in
		-- config/keymaps.lua, which LazyVim loads last (after its core keymaps),
		-- so these win without a re-apply hack.
		vim.g.tmux_navigator_no_mappings = 1
	end,
}
