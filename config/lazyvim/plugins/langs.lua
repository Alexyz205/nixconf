return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        cmake = { "gersemi" },
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
        lua = { "luacheck" },
        terraform = { "tflint", "terraform_validate" },
        tf = { "tflint", "terraform_validate" },
        cmake = { "gersemi" },
      },
    },
  },
}
