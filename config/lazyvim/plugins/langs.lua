vim.filetype.add({
	pattern = {
		[".*/%.github/workflows/.*%.yml"] = "yaml.ghaction",
		[".*/%.github/workflows/.*%.yaml"] = "yaml.ghaction",
	},
})

return {
	{
		-- LazyVim's cmake extra expects neocmakelsp, which nixpkgs doesn't ship.
		-- Use the packaged cmake-language-server instead.
		"neovim/nvim-lspconfig",
		optional = true,
		opts = {
			servers = {
				neocmake = { enabled = false },
				cmake = {},
			},
		},
	},
	{
		"stevearc/conform.nvim",
		optional = true,
		opts = {
			formatters_by_ft = {
				cmake = { "gersemi" },
				sh = { "shfmt" },
				bash = { "shfmt" },
				nix = { "nixfmt" },
				lua = { "stylua" },
				python = { "ruff_format" },
				markdown = { "prettierd", "markdownlint-cli2" },
				["markdown.mdx"] = { "prettierd", "markdownlint-cli2" },
			},
		},
	},
	{
		"mfussenegger/nvim-lint",
		optional = true,
		opts = {
			linters = {
				gersemi = {
					cmd = "gersemi",
					args = { "--check" },
					stdin = false,
					stream = "stderr",
					ignore_exitcode = true,
					parser = function(output, _bufnr)
						local diagnostics = {}
						for line in output:gmatch("[^\r\n]+") do
							if line:match("would be reformatted") then
								table.insert(diagnostics, {
									lnum = 0,
									col = 0,
									source = "gersemi",
									severity = vim.diagnostic.severity.WARN,
									message = "cmake file would be reformatted",
								})
							end
						end
						return diagnostics
					end,
				},
			},
			linters_by_ft = {
				sh = { "shellcheck" },
				bash = { "shellcheck" },
				nix = { "statix", "deadnix" },
				yaml = { "yamllint" },
				["yaml.ghaction"] = { "actionlint", "yamllint" },
				["yaml.ansible"] = { "ansible_lint", "yamllint" },
				lua = { "luacheck" },
				markdown = { "markdownlint-cli2" },
				python = { "ruff" },
				dockerfile = { "hadolint" },
				terraform = { "tflint", "terraform_validate" },
				tf = { "tflint", "terraform_validate" },
				cmake = { "gersemi" },
			},
		},
	},
}
