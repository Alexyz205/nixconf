local function run(cmd)
	vim.cmd("botright 14split")
	vim.fn.termopen(cmd)
end

vim.keymap.set("n", "<leader>xg", function()
	run({ "gitleaks", "dir", ".", "--no-banner", "--redact", "--config", ".gitleaks.toml" })
end, { desc = "gitleaks: scan repo for secrets" })

vim.keymap.set("n", "<leader>xt", function()
	run({
		"trivy",
		"fs",
		"--scanners",
		"misconfig,secret",
		"--severity",
		"HIGH,CRITICAL",
		"--skip-files",
		"config/ssh/id_ed25519_sk_rk_alexis-perso",
		"--skip-db-update",
		".",
	})
end, { desc = "trivy: config/secret scan" })

return {}
