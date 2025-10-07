# checkpatch.nvim 

A checkpatch plugin for Neovim. Nothing more. Nothing less.

## Installation

### lazy.nvim
```lua
{
  "qrutyy/checkpatch.nvim",
  -- or: dir = "/absolute/path/to/checkpatch.nvim" for a local checkout
  ft = { "c" },
  cmd = { "Checkpatch" },
  opts = {
    -- you can override default keymaps here
    -- mappings = { run = { keys = "<leader>cp" }, next = { keys = "," }, prev = { keys = "<" } }
  },
  config = function(_, opts)
    require("plugins.checkpatch").setup(opts)
  end,
}
```

### packer.nvim
```lua
use {
  "qrutyy/checkpatch.nvim",
  config = function()
    require("plugins.checkpatch").setup({
      -- mappings = { run = { keys = "<leader>cp" } }
    })
  end,
}
```

### vim-plug
```vim
Plug 'qrutyy/checkpatch.nvim'
" In your init.vim/init.lua after plug#end():
lua << EOF
require('plugins.checkpatch').setup({
  -- mappings = { run = { keys = '<leader>cp' } }
})
EOF
```

#### Supported Neovim versions:

- NVIM v0.11.1

#### Dependencies:

- `curl` (_mandatory_) download checkpatch

## Usage

Simple ah

```vim
:Checkpatch [options]
```

Example:
```vim
:Checkpatch set log strict codespell no-tree diff
```

Default keymaps (can be overridden in setup):

- <leader>cp: Run :Checkpatch
- `.`: Next checkpatch remark
- `shift` + `,`: Previous checkpatch remark

## Options
- `set` - to set & remember the options configuration
- `log` - save stdout to file in (`~/.local/share/nvim/checkpatch-logs/`)
- `no-tree` - run outside of kernel source tree
- `codespell` - use codespell
- `strict` - strict mode
- `quiet` - guess what (always on save)
- `diff` - check only the diff on the current branch

If you execute it with no options (same with hotkey) - it will use the prev cached config.
