# databricks.nvim

Neovim extension for Databricks. Currently supports DAB project detection and Databricks CLI profile resolution — more features planned.

This is not an official Databricks extension.

## Features

- **DAB project detection** — Automatically detects [Declarative Automation Bundles](https://docs.databricks.com/aws/en/dev-tools/bundles/) projects by finding `databricks.yml` in the workspace root.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'vahor/databricks.nvim',
  lazy = false, -- needed to set up DirChanged/BufEnter autocmds on startup
  opts = {
    -- See Configuration section below
  },
}
```

## Configuration

```lua
require("databricks").setup({
  -- Auto-detect DAB projects on DirChanged/BufEnter (default: true)
  auto_detect = true,

  -- Filename that identifies a DAB project root (default: "databricks.yml")
  dab_file = "databricks.yml",

  -- Databricks CLI profile to use (nil = auto-resolve from env or databricks.yml)
  profile = nil,

  -- Called after initial detection / config is ready
  on_attach = function()
    vim.notify("databricks.nvim ready")
  end,
})
```

## Profile resolution order

1. `profile` option in `setup()`
2. `nil` (no profile resolved)


## License

MIT
