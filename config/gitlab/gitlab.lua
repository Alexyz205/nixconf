-- Per-host GitLab personal access tokens live in glab's config
-- (~/.config/glab-cli/config.yml, rendered from sops), so this set only
-- whitelists the instances the plugin should activate for.
local gitlab_hosts = {
	["git.dxyz.pro"] = true,
	["gitlab.alexyz.org"] = true,
}

-- Resolve the remote URL, preferring "upstream" (forks) over "origin".
local function remote_url()
	for _, remote in ipairs({ "upstream", "origin" }) do
		local out = vim.fn.system({ "git", "remote", "get-url", remote })
		if vim.v.shell_error == 0 and out ~= "" then
			return vim.trim(out)
		end
	end
	return nil
end

-- Extract the hostname from an ssh (`git@host:path`) or url (`https://host/path`) remote.
local function remote_host()
	local url = remote_url()
	if not url then
		return nil
	end
	local host = url:match("^[%w+.-]+://([^/]+)") or url:match("^[^@]+@([^:/]+)")
	return host and host:gsub("^.*@", ""):gsub(":.*$", "") or nil
end

-- Read the host's PAT from glab's store instead of the environment, so the
-- token exists only in glab/nvim and never in every child process.
local function glab_token(host)
	if vim.fn.executable("glab") == 0 then
		return nil
	end
	local out = vim.fn.system({ "glab", "config", "get", "token", "--host", host })
	if vim.v.shell_error ~= 0 then
		return nil
	end
	out = vim.trim(out)
	return out ~= "" and out or nil
end

return {
	"harrisoncramer/gitlab.nvim",
	-- Only load in repos hosted on a recognised GitLab instance; the plugin and
	-- its dependencies stay unloaded for GitHub/local repos.
	cond = function()
		if vim.fn.executable("git") == 0 or vim.fn.executable("glab") == 0 then
			return false
		end
		return gitlab_hosts[remote_host()] ~= nil
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
		local host = remote_host()

		-- Connection: auto-detect remote (upstream for forks, origin otherwise)
		local function detect_remote()
			local remotes = vim.fn.system("git remote")
			return remotes:find("upstream") and "upstream" or "origin"
		end

		require("gitlab").setup({
			-- Pick the API URL and PAT stored by glab for whichever GitLab host
			-- this repo is on.
			auth_provider = function()
				local token = glab_token(host)
				if not token then
					return nil,
						nil,
						("no glab credential for %s (run: glab auth login --hostname %s)"):format(
							tostring(host),
							tostring(host)
						)
				end
				return token, "https://" .. host, nil
			end,

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
