# Configuration

```lua
require("databricks").setup({
  -- Auto-detect DAB projects on DirChanged/BufEnter (default: true)
  auto_detect = true,

  -- Databricks CLI profile to use (default: nil).
  -- Can be a string, a function() -> string, or nil.
  -- Resolution order: function → $DATABRICKS_PROFILE → string.
  profile = nil,

  -- Path to a Python virtualenv to activate before running commands (default: nil).
  -- Can be a string, a function() -> string, or nil.
  -- Resolution order: function → $DATABRICKS_NVIM_VENV → string.
  -- Sets VIRTUAL_ENV and prepends venv/bin to PATH for all CLI invocations.
  venv = nil,

  -- DAB-specific configuration
  dab = {
    -- Schema source for yaml-language-server (URL, local path, or false to disable)
    -- Set to a local path to use `databricks bundle schema > schema.json`
    -- NOTE: your language server probably already knows the latest schema. This is mostly useful when used with a local path
    schema = "https://raw.githubusercontent.com/databricks/cli/refs/heads/main/bundle/schema/jsonschema.json",
  },

  -- Spark type injection for Python buffers (requires pyright or basedpyright)
  spark = {
    -- Inject `spark` as SparkSession in all Python buffers (default: true)
    inject = true,
  },

  -- Default flags for CLI subcommands
  commands = {
    deploy = {
      force = false,
      auto_approve = false,
      target = nil, -- e.g. "dev", "staging", "prod"
    },
    run = {
      -- Cluster ID for Python execution. String, function, or nil.
      -- Resolution: --cluster-id flag → function → $DATABRICKS_NVIM_CLUSTER_ID → string.
      cluster_id = nil,
      -- SQL warehouse ID. String, function, or nil.
      -- Resolution: --warehouse-id flag → function → $DATABRICKS_NVIM_WAREHOUSE_ID → string.
      warehouse_id = nil,
    },
  },

  -- Called after initial detection / config is ready (default: nil)
  on_attach = nil,
})
```

## Environment variables

| Variable | Used by | Description |
|---|---|---|
| `DATABRICKS_PROFILE` | `profile` | Databricks CLI profile name |
| `DATABRICKS_NVIM_VENV` | `venv` | Path to Python virtualenv |
| `DATABRICKS_NVIM_CLUSTER_ID` | `commands.run.cluster_id` | Cluster ID for Python execution |
| `DATABRICKS_NVIM_WAREHOUSE_ID` | `commands.run.warehouse_id` | SQL warehouse ID |

Env vars are checked when the corresponding config option is a string or nil.
Config functions take precedence over env vars.
