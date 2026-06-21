# Configuration

```lua
require("databricks").setup({
  -- Auto-detect DAB projects on DirChanged/BufEnter (default: true).
  -- When enabled, LSP schemas and stubs are injected on enter and removed on leave.
  auto_detect = true,

  -- Databricks CLI profile (default: nil).
  -- String, function, or nil. Resolution: config > $DATABRICKS_PROFILE.
  profile = nil,

  -- Python virtualenv path (default: nil).
  -- String, function, or nil. Resolution: config > $DATABRICKS_NVIM_VENV.
  venv = nil,

  -- Default `--target` for bundle commands: deploy, resources, variables (default: nil).
  -- A per-invocation `--target <name>` flag overrides this.
  target = nil,

  -- DAB-specific configuration
  dab = {
    -- Schema URL for yamlls, or false to disable
    schema = "https://raw.githubusercontent.com/databricks/cli/refs/heads/main/bundle/schema/jsonschema.json",
  },

  -- Directory for run logs (default: stdpath("data") .. "/databricks.nvim").
  -- Logs are stored in a subdirectory named after the project root or cwd.
  log = {
    dir = vim.fn.stdpath("data") .. "/databricks.nvim",
  },

  -- Spark type injection
  spark = {
    inject = true,
  },

  -- Unity Catalog completion
  completion = {
    uc = {
      enabled = true,                        -- Enable UC completion
      catalogs = "auto",                     -- "auto", array of names/globs, function, or comma-separated string
      schemas = "auto",                      -- Same as catalogs but matches full schema name (catalog.schema)
      filetypes = { "sql", "python", "markdown" },  -- File types to enable completion in
    },
  },

  -- Default CLI flags
  commands = {
    deploy = {
      force = false,
      auto_approve = false,
    },
    run = {
      cluster_id = nil,    -- Resolution: flags > config > env var
      warehouse_id = nil,  -- Resolution: flags > config > env var
    },
    log = {
      open = true,
    },
  },

  on_attach = nil,
})
```

_Note: every resolved config value can be either a string, a function returning a string, or nil._

## Environment variables

| Variable | Config field | Description |
|---|---|---|
| `DATABRICKS_PROFILE` | `profile` | Databricks CLI profile name |
| `DATABRICKS_NVIM_VENV` | `venv` | Path to Python virtualenv |
| `DATABRICKS_NVIM_CLUSTER_ID` | `commands.run.cluster_id` | Cluster ID for Python execution |
| `DATABRICKS_NVIM_WAREHOUSE_ID` | `commands.run.warehouse_id` | SQL warehouse ID |
| `DATABRICKS_NVIM_UC_CATALOGS` | `completion.uc.catalogs` | Comma-separated catalog names/globs for UC completion |
| `DATABRICKS_NVIM_UC_SCHEMAS` | `completion.uc.schemas` | Comma-separated schema full_names/globs for UC completion |

Env vars are checked when the config value is a string or nil. Config functions take precedence over env vars.

## Unity Catalog completion

The plugin fetches catalog/schema/table/column metadata from `databricks` CLI and caches it to disk.
It provides a [blink.cmp](https://github.com/saghen/blink.cmp) source for autocompletion in SQL files
(and optionally Python, Markdown, or any filetype configured in `filetypes`).

Add the source to your blink.cmp config:

```lua
sources = {
  default = { "lsp", "path", "snippets", "databricks_uc" },
  providers = {
    databricks_uc = {
      name = "DatabricksUC",
      module = "databricks.completion.blink",
    },
  },
},
```

The `catalogs` config supports exact names, glob patterns (`*` and `?`), or `"auto"` for all:

```lua
-- Only include catalogs matching a pattern
completion = {
  uc = {
    catalogs = { "dev_*", "prod_sales" },
  },
},
```

Use `:Databricks refresh` to re-fetch metadata and update the cache.
