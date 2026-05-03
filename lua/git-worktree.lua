local M = {}

local config = {
	auto_install = true,
}

function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})
end

-- notification helper function
local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "git-worktree" })
end

local function run_git(args)
	local command = vim.list_extend({ "git" }, args)
	return vim.system(command, { text = true }):wait()
end

local function git_output(args)
	local result = run_git(args)

	if result.code ~= 0 then
		notify(result.stderr, vim.log.levels.ERROR)
		return {}
	end

	return vim.split(result.stdout, "\n", { trimempty = true })
end

local function get_git_root()
	local result = run_git({ "rev-parse", "--show-toplevel" })

	if result.code ~= 0 then
		notify("Not inside git repository", vim.log.levels.ERROR)
		return nil
	end

	return vim.trim(result.stdout)
end

local function list_worktrees()
	local worktrees = {}
	local current = {}

	local git_worktree_list_output = git_output({ "worktree", "list", "--porcelain" })

	for _, line in ipairs(git_worktree_list_output) do
		local extract_path = line:match("^worktree (.+)")
		local extract_branch = line:match("^branch refs/heads/(.+)")

		-- each block starts with "worktree"
		-- add path and branch to current table
		-- when reaching the next block, add current table to worktrees table
		if extract_path then
			if current.path then
				worktrees[#worktrees + 1] = current
			end

			current = { path = extract_path }
		elseif extract_branch then
			current.branch = extract_branch
		elseif line == "bare" or line == "detached" then
			current.branch = line
		end
	end

	-- manually add the last current table to the worktrees table
	-- because loop ends and there are no more blocks
	if current.path then
		worktrees[#worktrees + 1] = current
	end

	return worktrees
end

local function get_worktree_items()
	return vim.tbl_map(function(worktree)
		return {
			text = string.format("%s  %s", worktree.branch or "unknown", worktree.path),
			path = worktree.path,
			branch = worktree.branch,
		}
	end, list_worktrees())
end

local function switch_worktree(path)
	local current_buffer = vim.api.nvim_buf_get_name(0)
	local current_git_repo = get_git_root()

	if not current_git_repo then
		return
	end

	local relative_path

	-- get current buffer relative path
	if vim.startswith(current_buffer, current_git_repo) then
		relative_path = current_buffer:sub(#current_git_repo + 2)
	end

	-- if directory exists, change to it
	vim.api.nvim_set_current_dir(path)

	-- clears jump list
	vim.cmd.clearjumps()

	if not relative_path then
		vim.cmd.edit(".")
		return
	end

	-- if file in relative path exists, change to it
	local new_path = path .. "/" .. relative_path
	if vim.uv.fs_stat(new_path) then
		vim.cmd.edit(vim.fn.fnameescape(new_path))
	else
		vim.cmd.edit(".")
	end
end

local function create_worktree(path, branch, upstream)
	if vim.uv.fs_stat(path) then
		notify("Directory already exists", vim.log.levels.ERROR)
		return false
	end

	local target = "HEAD"

	-- if upstream is set, add it to the args, else use HEAD as default
	if upstream ~= "" then
		target = upstream .. "/" .. branch
	end

	local args = { "worktree", "add", "-b", branch, path, target }

	local result = run_git(args)

	if result.code ~= 0 then
		local message = result.stderr or result.stdout or "git command failed"
		notify(vim.trim(message), vim.log.levels.ERROR)
		return false
	end

	return path
end

local function run_install(path)
	local commands = {
		["package-lock.json"] = { "npm", "install" },
		["pnpm-lock.yaml"] = { "pnpm", "install" },
		["yarn.lock"] = { "yarn", "install" },
		["bun.lock"] = { "bun", "install" },
		["bun.lockb"] = { "bun", "install" },
	}

	for lockfile, command in pairs(commands) do
		if vim.uv.fs_stat(path .. "/" .. lockfile) then
			notify("Installing dependencies: " .. table.concat(command, " "))
			vim.system(command, { cwd = path, text = true })
			return
		end
	end

	notify("No lockfile found, skipping install")
end

function M.switch()
	if not get_git_root() then
		return
	end

	if not Snacks or not Snacks.picker then
		notify("snacks.nvim is required for git-worktree picker", vim.log.levels.ERROR)
		return
	end

	Snacks.picker.pick({
		title = "Git Worktrees",
		format = "text",
		items = get_worktree_items(),
		confirm = function(picker, item)
			picker:close()

			if item then
				switch_worktree(item.path)
			end
		end,
	})
end

function M.create()
	if not get_git_root() then
		return
	end

	vim.ui.input({ prompt = "Branch name: " }, function(branch)
		if branch == nil then
			return
		end

		branch = vim.trim(branch)
		if branch == "" then
			return
		end

		-- default path is ../project-wt_branch-name
		local default_path = "../" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t") .. "-wt_" .. branch
		vim.ui.input({ prompt = "Worktree path: ", default = default_path }, function(path)
			if path == nil then
				return
			end

			path = vim.trim(path)
			if path == "" then
				return
			end

			vim.ui.input({ prompt = "Upstream remote (blank for new local branch): " }, function(upstream)
				if upstream == nil then
					return
				end

				upstream = vim.trim(upstream)

				local new_worktree = create_worktree(path, branch, upstream)

				if new_worktree then
					switch_worktree(new_worktree)

					if config.auto_install then
						run_install(new_worktree)
					end
				end
			end)
		end)
	end)
end

return M
