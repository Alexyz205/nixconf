local opt = vim.opt
local g = vim.g

opt.colorcolumn = "80"
opt.softtabstop = 2
opt.scrolloff = 8
opt.hlsearch = false
opt.swapfile = false
opt.updatetime = 50

g.snacks_animate = false
g.lazyvim_python_lsp = "basedpyright"

vim.filetype.add({ extension = { ino = "cpp" } })

-- No installed plugin needs luarocks, and it trips `checkhealth lazy`.
require("lazy.core.config").options.rocks.enabled = false
