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
