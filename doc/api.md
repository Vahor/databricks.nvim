## Lua API

```lua
local databricks = require("databricks")

-- DAB detection
databricks.dab.is_dab_project()   --> boolean
databricks.dab.find_root()        --> string | nil
databricks.dab.is_dab_root(path)  --> boolean

-- Profile
databricks.profile.resolve()      --> string | nil

-- Toggle LSP injection based on current DAB project state (called automatically)
databricks.toggle_inject()

-- YAML schema (called automatically by toggle_inject)
databricks.yaml.inject()
databricks.yaml.remove()

-- Spark type stubs (called automatically by toggle_inject)
databricks.python.inject()
databricks.python.remove()

-- Refresh vim.g state
databricks.refresh()
```
