return {
  {
    "lukas-reineke/indent-blankline.nvim",
    opts = {
      enabled = true,
      debounce = 200,
      viewport_buffer = { min = 30 },
      indent = {
        char = "│",
        tab_char = "│",
        -- Rainbow guides per indent level. The Rainbow* and IblScope groups
        -- are defined in the config hook below from the catppuccin palette,
        -- so they always exist when ibl validates them at setup.
        highlight = {
          "RainbowRed",
          "RainbowYellow",
          "RainbowBlue",
          "RainbowOrange",
          "RainbowGreen",
          "RainbowViolet",
          "RainbowCyan",
        },
        smart_indent_cap = true,
        priority = 1,
        repeat_linebreak = true,
      },
      whitespace = {
        highlight = {
          "RainbowRed",
          "RainbowYellow",
          "RainbowBlue",
          "RainbowOrange",
          "RainbowGreen",
          "RainbowViolet",
          "RainbowCyan",
        },
        remove_blankline_trail = true,
      },
      scope = {
        enabled = true,
        show_start = true,
        show_end = true,
        show_exact_scope = true,
        injected_languages = true,
        highlight = "IblScope",
        priority = 1024,
      },
      exclude = {
        filetypes = {
          "help",
          "alpha",
          "dashboard",
          "neo-tree",
          "Trouble",
          "trouble",
          "lazy",
          "mason",
          "notify",
          "toggleterm",
          "lazyterm",
        },
        buftypes = {
          "terminal",
          "nofile",
          "quickfix",
          "prompt",
        },
      },
    },
    config = function(_, opts)
      local hooks = require("ibl.hooks")

      -- Define the indent-guide highlight groups from the catppuccin palette
      -- so they follow the active flavour. Registered as a HIGHLIGHT_SETUP
      -- hook: ibl re-runs it on setup and on every colorscheme change.
      hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        local ok, pal = pcall(require, "catppuccin.palettes")
        local c = ok and pal.get_palette() or {}

        local rainbow = {
          Red = c.red or "#f38ba8",
          Yellow = c.yellow or "#f9e2af",
          Blue = c.blue or "#89b4fa",
          Orange = c.peach or "#fab387",
          Green = c.green or "#a6e3a1",
          Violet = c.mauve or "#cba6f7",
          Cyan = c.teal or "#94e2d5",
        }
        for name, fg in pairs(rainbow) do
          vim.api.nvim_set_hl(0, "Rainbow" .. name, { fg = fg })
        end
        vim.api.nvim_set_hl(0, "IblScope", { fg = c.lavender or "#b4befe" })
      end)

      -- Cleaner look: keep the first indent level as a plain space / tab
      hooks.register(hooks.type.WHITESPACE, hooks.builtin.hide_first_space_indent_level)
      hooks.register(hooks.type.WHITESPACE, hooks.builtin.hide_first_tab_indent_level)

      require("ibl").setup(opts)
    end,
  },
}