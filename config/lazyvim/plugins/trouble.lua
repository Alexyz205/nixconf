-- lazyvim-nix names dev-mode dirs `owner--repo` (e.g. folke--trouble.nvim),
-- so lazy.nvim cannot map `require("trouble")` back to the plugin. Loading it
-- eagerly puts it on the runtimepath before LazyVim's lualine config runs.
return {
	{
		"folke/trouble.nvim",
		lazy = false,
	},
}
