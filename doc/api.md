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
