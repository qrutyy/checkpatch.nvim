# checkpatch.nvim 

A checkpatch plugin for Neovim. Nothing more. Nothing less.

[Features](#features) • [Install](#install) 

## Install (tmp)

- lazy.nvim:

Install locally and move to nvim config folder:
```sh
git clone https://github.com/qrutyy/checkpatch.nvim && mv checkpatch.nvim /path/to/nvim/cfg/plugins/
```

Add the plugin to plugin manager:
```lua
 {
   "local/checkpatch",
   dir = "/path/to/plugin/",
   lazy = false,        -- load at startup so autocmd/command are defined
   cmd = { "Checkpatch" }, -- also allow lazy-load on command if needed
   ft = { "c" },        -- ensure loaded when editing C files
 },
```

- packer.nvim - **WIP**
- vim-plug.nvim - **WIP**

#### Supported Neovim versions:

- NVIM v0.11.1

#### Dependencies:

- `curl` (_mandatory_) download checkpatch

## Usage

Simple ah

```vim
:Checkpatch [options]
```

Iterating through the errors - **WIP**

## Options
- `log` - save stdout to file in (`~/.local/share/nvim/checkpatch-logs/`)
- `no-tree` - run outside of kernel source tree
- `codespell` - use codespell
- `strict` - strict mode
- `quiet` - guess what (always on save)
- `check-all` - check all the files in the current directory (**WIP**)

If you with no options - it will use the prev cached config.
