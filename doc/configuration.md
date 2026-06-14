# Configuration

```lua
require("databricks").setup({
  -- Auto-detect DAB projects on DirChanged/BufEnter (default: true)
  auto_detect = true,

  -- Databricks CLI profile to use (default: nil — auto-detect from env)
  profile = nil,

  -- DAB-specific configuration
  dab = {
    -- Filename that identifies a DAB project root (default: "databricks.yml")
    file = "databricks.yml",

    -- Schema source for yaml-language-server (URL, local path, or false to disable)
    -- Set to a local path to use `databricks bundle schema > schema.json`
    -- NOTE: your language server probably already knows the latest schema. This is mostly useful when used with a local path or custom file.
    schema = "https://raw.githubusercontent.com/databricks/cli/refs/heads/main/bundle/schema/jsonschema.json",
  },

  -- Called after initial detection / config is ready (default: nil)
  on_attach = nil,
})
```
