-- ============================================================================
-- Disabled Plugins Configuration
-- ============================================================================
-- Plugins that are disabled or have features turned off
-- Used to override LazyVim defaults that don't fit our workflow
-- ============================================================================

return {
	-- Disable bufferline (prefer native tabline or other alternatives)
	{
		"akinsho/bufferline.nvim",
		enabled = false,
	},

	-- Disable tokyonight theme (using Catppuccin instead)
	{
		"folke/tokyonight.nvim",
		enabled = false,
	},

	-- Disable the bogus 'nvim' plugin: lazyvim-nix mis-resolves the
	-- "catppuccin/nvim" spec to nixpkgs' vimPlugins.nvim, which appears as an
	-- eager dev plugin and fails with "Lua module not found for config of nvim".
	{
		"nvim",
		enabled = false,
	},

	-- Disable snacks.nvim explorer (using Yazi instead)
	{
		"folke/snacks.nvim",
		opts = {
			explorer = { enabled = false },
		},
	},
}
