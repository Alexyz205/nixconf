return {
  "pwntester/octo.nvim",
  opts = {
    default_remote = { "upstream", "origin" },
  },
  keys = {
    { "<leader>op", "<CMD>Octo pr list<CR>", desc = "GitHub: List Pull Requests" },
    { "<leader>oi", "<CMD>Octo issue list<CR>", desc = "GitHub: List Issues" },
    { "<leader>oc", "<CMD>Octo pr checks<CR>", desc = "GitHub: PR Checks" },
  },
}