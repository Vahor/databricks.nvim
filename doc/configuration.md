# Configuration

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
