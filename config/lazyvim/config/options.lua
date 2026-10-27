local opt = vim.opt
local g = vim.g

opt.softtabstop = 2
opt.scrolloff = 8
opt.updatetime = 200

g.snacks_animate = false
g.lazyvim_python_lsp = "basedpyright"

vim.filetype.add({ extension = { ino = "cpp" } })

-- Keep swap files for crash recovery, but out of the project tree.
local swapdir = vim.fn.stdpath("state") .. "/swap"
vim.fn.mkdir(swapdir, "p")
opt.directory = swapdir .. "//"

-- A global colorcolumn is noisy in JSON/TOML; only show it for code/prose.
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("nixconf_colorcolumn", { clear = true }),
	pattern = {
		"c",
		"cpp",
		"cuda",
		"go",
		"lua",
		"nix",
		"python",
		"rust",
		"sh",
		"bash",
		"zsh",
		"terraform",
		"hcl",
		"cmake",
		"dockerfile",
		"yaml.ansible",
		"markdown",
		"gitcommit",
	},
	callback = function()
		vim.opt_local.colorcolumn = "80"
	end,
})

-- No installed plugin needs luarocks, and it trips `checkhealth lazy`.
require("lazy.core.config").options.rocks.enabled = false
