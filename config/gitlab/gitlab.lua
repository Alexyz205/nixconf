return {
	"harrisoncramer/gitlab.nvim",
	-- Only load gitlab.nvim in repos hosted on the self-hosted GitLab
	-- (git.dxyz.pro). `cond` is evaluated at startup: the plugin (and its
	-- dependencies) stay unloaded for GitHub/local repos.
	cond = function()
		if vim.fn.executable("git") == 0 then
			return false
		end
		local out = vim.fn.system({ "git", "remote", "-v" })
		if vim.v.shell_error ~= 0 then
			return false
		end
		return out:find("git.dxyz.pro", 1, true) ~= nil
	end,
	dependencies = {
		"MunifTanjim/nui.nvim",
		"nvim-lua/plenary.nvim",
		"dlyongemallo/diffview-plus.nvim",
		"nvim-tree/nvim-web-devicons",
	},
	build = function()
		require("gitlab.server").build(true)
	end,
	config = function()
		-- Detect the right remote: prefer "upstream" if it exists, else "origin"
		local function detect_remote()
			local result = vim.fn.system("git remote")
			if result:find("upstream") then
				return "upstream"
			end
			return "origin"
		end

		require("gitlab").setup({
			-- Auth provider for self-hosted GitLab
			-- Reads token from GITLAB_TOKEN env var, points API at git.dxyz.pro
			auth_provider = function()
				local token = os.getenv("GITLAB_TOKEN")
				if not token then
					return nil, nil, "GITLAB_TOKEN environment variable is not set"
				end
				return token, "https://git.dxyz.pro", nil
			end,

			-- Connection: auto-detect remote (upstream for forks, origin otherwise)
			connection_settings = {
				remote = detect_remote(),
			},
		})

		-- Reviewer keymaps (visual mode for comment/suggest on selected lines)
		-- All global `gl*` keymaps are registered automatically by the plugin defaults
		local gitlab = require("gitlab")
		vim.keymap.set("v", "glcc", gitlab.create_multiline_comment, { desc = "GitLab: Comment on lines" })
		vim.keymap.set("v", "glcs", gitlab.create_comment_suggestion, { desc = "GitLab: Suggest on lines" })
	end,
}
