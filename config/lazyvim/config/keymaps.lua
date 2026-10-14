local map = vim.keymap.set

map("i", "<C-b>", "<ESC>^i", { desc = "Move to line start" })
map("i", "<C-e>", "<End>", { desc = "Move to line end" })
map("i", "<C-h>", "<Left>", { desc = "Move left" })
map("i", "<C-l>", "<Right>", { desc = "Move right" })
map("i", "<C-j>", "<Down>", { desc = "Move down" })
map("i", "<C-k>", "<Up>", { desc = "Move up" })

map("n", "<C-s>", "<cmd>w<CR>", { desc = "Save file" })
map("n", "<C-S>", "<cmd>wa<CR>", { desc = "Save all files" })

map("n", "<C-c>", "<cmd>%y+<CR>", { desc = "Yank whole buffer" })

map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down (centered)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up (centered)" })

map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
map("n", "J", "mzJ`z", { desc = "Join lines" })

map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
map("n", "N", "Nzzzv", { desc = "Prev search result (centered)" })

map("x", "<leader>p", [["_dP]], { desc = "Paste without yanking" })
map({ "n", "v" }, "<leader>y", [["+y]], { desc = "Yank to system clipboard" })
map("n", "<leader>Y", [["+Y]], { desc = "Yank line to system clipboard" })
map({ "n", "v" }, "<leader>d", [["_d]], { desc = "Delete without yanking" })

map("n", "<leader><leader>", "<cmd>so<CR>", { desc = "Reload file" })

map("n", "<C-h>", "<cmd>TmuxNavigateLeft<cr>", { desc = "Go to left window" })
map("n", "<C-j>", "<cmd>TmuxNavigateDown<cr>", { desc = "Go to lower window" })
map("n", "<C-k>", "<cmd>TmuxNavigateUp<cr>", { desc = "Go to upper window" })
map("n", "<C-l>", "<cmd>TmuxNavigateRight<cr>", { desc = "Go to right window" })
map("n", "<C-\\>", "<cmd>TmuxNavigatePrevious<cr>", { desc = "Go to previous window" })
