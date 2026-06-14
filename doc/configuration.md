# Configuration

```lua
require("databricks").setup({
  -- Auto-detect DAB projects on DirChanged/BufEnter (default: true)
  auto_detect = true,

  -- Databricks CLI profile to use (default: nil — auto-detect from env)
  profile = nil,

  -- DAB-specific configuration
  dab = {
    -- Schema source for yaml-language-server (URL, local path, or false to disable)
    -- Set to a local path to use `databricks bundle schema > schema.json`
    -- NOTE: your language server probably already knows the latest schema. This is mostly useful when used with a local path
    schema = "https://raw.githubusercontent.com/databricks/cli/refs/heads/main/bundle/schema/jsonschema.json",
  },

  -- Default flags for CLI subcommands
  commands = {
    deploy = {
      force = false,
      auto_approve = false,
      target = nil, -- e.g. "dev", "staging", "prod"
    },
    run = {
      cluster_id = nil,   -- required for :Databricks run on .py files
      warehouse_id = nil, -- required for :Databricks run on .sql files
    },
  },

  -- Called after initial detection / config is ready (default: nil)
  on_attach = nil,
})
```
