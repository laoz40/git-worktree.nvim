if vim.g.loaded_git_worktree_nvim then
	return
end
vim.g.loaded_git_worktree_nvim = true

vim.api.nvim_create_user_command("GitWorktreeSwitch", function()
	require("git-worktree").switch()
end, {})

vim.api.nvim_create_user_command("GitWorktreeCreate", function()
	require("git-worktree").create()
end, {})
