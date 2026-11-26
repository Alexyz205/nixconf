return {
	{
		-- LazyVim's clangd extra sets `opts` on nvim-dap, and nvim-dap has no
		-- `setup()`. Without an explicit config, lazy.nvim auto-configures it
		-- with `require("dap").setup(opts)` and fails. The clangd opts mutate
		-- `dap` directly, so an empty config is enough to skip that call.
		"mfussenegger/nvim-dap",
		config = function() end,
	},
}
