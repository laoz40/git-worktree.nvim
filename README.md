# git-worktree.nvim

Made my own plugin to create and switch between git worktrees.
Uses [snacks.nvim](https://github.com/folke/snacks.nvim) picker. Auto installs packages when a lockfile is found.

Inspired by [ThePrimagen's git-worktree.vim](https://github.com/ThePrimeagen/git-worktree.vim), just wanted to make my own.

## Installation

```lua
vim.pack.add({
	{ src = "https://github.com/laoz40/git-worktree.nvim" },
})

require("git-worktree").setup({ auto_install = true })
```

## Setup


| Option | Default | Description |
| --- | --- | --- |
| `auto_install` | `true` | Automatically run package install after creating a worktree when a lockfile is found. |

Supported lockfiles:

- `package-lock.json` → `npm install`
- `pnpm-lock.yaml` → `pnpm install`
- `yarn.lock` → `yarn install`
- `bun.lock` / `bun.lockb` → `bun install`

## Usage

Commands:

```vim
:GitWorktreeSwitch
:GitWorktreeCreate
```

Lua API:

```lua
require("git-worktree").switch()
require("git-worktree").create()
```

Example keymaps:

```lua
vim.keymap.set("n", "<leader>gw", function()
	require("git-worktree").switch()
end, { desc = "Git worktree switch" })

vim.keymap.set("n", "<leader>gW", function()
	require("git-worktree").create()
end, { desc = "Git worktree create" })
```

