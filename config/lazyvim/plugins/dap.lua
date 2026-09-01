return {
  {
    "mfussenegger/nvim-dap",
    -- The dap.core extra (pulled in by lang.clangd) guards its mason-nvim-dap
    -- setup with `LazyVim.has("mason-nvim-dap.nvim")`. That check only looks at
    -- the spec table, so it still returns true for the disabled plugin and
    -- tries to require a module that was never loaded -> `setup` on nil.
    -- Mason is disabled in this Nix setup, so drop that block entirely.
    config = function()
      vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })

      for name, sign in pairs(LazyVim.config.icons.dap) do
        sign = type(sign) == "table" and sign or { sign }
        vim.fn.sign_define(
          "Dap" .. name,
          { text = sign[1], texthl = sign[2] or "DiagnosticInfo", linehl = sign[3], numhl = sign[3] }
        )
      end

      local vscode = require("dap.ext.vscode")
      local json = require("plenary.json")
      vscode.json_decode = function(str)
        return vim.json.decode(json.json_strip_comments(str))
      end
    end,
    -- lang.clangd hardcodes the `codelldb` adapter, which isn't packaged in
    -- nixpkgs. Use lldb-dap (from the `lldb` package) instead.
    opts = function()
      local dap = require("dap")
      if not dap.adapters["lldb-dap"] then
        dap.adapters["lldb-dap"] = {
          type = "server",
          host = "localhost",
          port = "${port}",
          executable = { command = "lldb-dap" },
        }
      end
      for _, lang in ipairs({ "c", "cpp" }) do
        dap.configurations[lang] = {
          {
            type = "lldb-dap",
            request = "launch",
            name = "Launch file",
            program = function()
              return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
            end,
            cwd = "${workspaceFolder}",
          },
          {
            type = "lldb-dap",
            request = "attach",
            name = "Attach to process",
            pid = require("dap.utils").pick_process,
            cwd = "${workspaceFolder}",
          },
        }
      end
    end,
  },
}
