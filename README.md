# databricks.nvim

Neovim extension for Databricks. DAB project detection, YAML schema support, and statusline integration.

This is not an official Databricks extension.

> [!IMPORTANT]
> This is a work in progress. Please report issues or feature requests on [GitHub](https://github.com/databricks.nvim/main/issues).
> Config changes are to be expected.


## Features

- **DAB project detection** — Automatically detects [Declarative Automation Bundles](https://docs.databricks.com/aws/en/dev-tools/bundles/) projects by finding `databricks.yml` in the workspace root.
- **YAML schema injection** — Hooks into `LspAttach` to give yaml-language-server the [Databricks bundle JSON Schema](https://raw.githubusercontent.com/databricks/cli/refs/heads/main/bundle/schema/jsonschema.json), enabling auto-completion and validation for `databricks.yml` files.

Using [Databricks cli](https://github.com/databricks/cli) as the backend.

### Planned Features

- Auto-deploy (DAB project) on save or with a command. (soon)
- Auto-validate on save. (soon)
- "Upload and run File" command for py and sql files on serverless or cluster. (later)

## Installation

Requires Neovim ≥ 0.12.

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'vahor/databricks.nvim',
  lazy = false,
  opts = {
    -- See Configuration below
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

  -- Databricks CLI profile to use (default: nil)
  profile = nil,

  -- Schema source for yaml-language-server (URL or local file path)
  -- Default: GitHub-hosted Databricks bundle schema
  -- Set to a local path to use `databricks bundle schema > schema.json`
  schema = "https://raw.githubusercontent.com/databricks/cli/refs/heads/main/bundle/schema/jsonschema.json",

  -- Called after initial detection / config is ready
  on_attach = function()
    vim.notify("databricks.nvim ready")
  end,
})
```

## Lua API

```lua
local databricks = require("databricks")

-- DAB detection
databricks.dab.is_dab_project()   --> boolean
databricks.dab.find_root()        --> string | nil (path containing databricks.yml)
databricks.dab.is_dab_root(path)  --> boolean

-- Profile
databricks.profile.resolve()      --> string | nil

-- YAML schema (called automatically in setup())
databricks.schema.inject()        --> sets up LspAttach autocmd for yamlls

-- Refresh vim.g state
databricks.refresh()
```

## License

MIT
