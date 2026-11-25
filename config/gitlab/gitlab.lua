-- gitlab.nvim builds its Go server on first use; the server has no cgo
-- dependencies, so force the pure-Go build instead of requiring gcc on NixOS.
vim.env.CGO_ENABLED = "0"

-- gitlab.nvim authenticates through the glab CLI: `glab auth login` stores the
-- OAuth token in the OS keyring, and the provider below reads it back for the
-- repository's host instead of exporting GITLAB_TOKEN to every child process.
local function gitlab_hosts()
	local hosts = {}
	for _, host in ipairs(vim.g.nixconf_gitlab_hosts or {}) do
		hosts[host] = true
	end
	return hosts
end

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

-- Read the host's token from glab's store instead of the environment, so the
-- token exists only in glab/nvim and never in every child process. OAuth access
-- tokens expire, so make an authenticated glab call first: that is what makes
-- glab refresh an expired token before it is read back.
local function glab_token(host)
	if vim.fn.executable("glab") == 0 then
		return nil
	end
	vim.system({ "glab", "auth", "status", "--hostname", host }, { text = true, timeout = 10000 }):wait()
	local result = vim.system({ "glab", "config", "get", "token", "--host", host }, { text = true }):wait()
	if result.code ~= 0 then
		return nil
	end
	local token = vim.trim(result.stdout or "")
	return token ~= "" and token or nil
end

return {
	"harrisoncramer/gitlab.nvim",
	-- Only load in repos hosted on a recognised GitLab instance; the plugin and
	-- its dependencies stay unloaded for GitHub/local repos.
	cond = function()
		if vim.fn.executable("git") == 0 or vim.fn.executable("glab") == 0 then
			return false
		end
		return gitlab_hosts()[remote_host()] ~= nil
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
					local err = ("no glab credential for %s (run: glab auth login --hostname %s)"):format(
						tostring(host),
						tostring(host)
					)
					vim.notify(err, vim.log.levels.ERROR)
					return nil, nil, err
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
