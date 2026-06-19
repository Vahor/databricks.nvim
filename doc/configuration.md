# Configuration

```lua
require("databricks").setup({
  -- Auto-detect DAB projects on DirChanged/BufEnter (default: true)
  auto_detect = true,

  -- Databricks CLI profile (default: nil).
  -- String, function, or nil. Resolution: function > $DATABRICKS_PROFILE > string.
  profile = nil,

  -- Python virtualenv path (default: nil).
  -- String, function, or nil. Resolution: function > $DATABRICKS_NVIM_VENV > string.
  venv = nil,

  -- DAB-specific configuration
  dab = {
    -- Schema URL for yamlls, or false to disable
    schema = "https://raw.githubusercontent.com/databricks/cli/refs/heads/main/bundle/schema/jsonschema.json",
  },

  -- Spark type injection
  spark = {
    inject = true,
  },

  -- Default CLI flags
  commands = {
    deploy = {
      force = false,
      auto_approve = false,
      target = nil,
    },
    run = {
      cluster_id = nil,    -- String, function, or nil
      warehouse_id = nil,  -- String, function, or nil
    },
  },

  on_attach = nil,
})
```

## Environment variables

| Variable | Config field | Description |
|---|---|---|
| `DATABRICKS_PROFILE` | `profile` | Databricks CLI profile name |
| `DATABRICKS_NVIM_VENV` | `venv` | Path to Python virtualenv |
| `DATABRICKS_NVIM_CLUSTER_ID` | `commands.run.cluster_id` | Cluster ID for Python execution |
| `DATABRICKS_NVIM_WAREHOUSE_ID` | `commands.run.warehouse_id` | SQL warehouse ID |

Env vars are checked when the config value is a string or nil. Config functions take precedence over env vars.
