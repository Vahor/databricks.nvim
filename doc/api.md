## Lua API

```lua
local databricks = require("databricks")

-- DAB detection
databricks.dab.is_dab_project()   --> boolean
databricks.dab.find_root()        --> string | nil
databricks.dab.is_dab_root(path)  --> boolean

-- Profile
databricks.profile.resolve()      --> string | nil

-- YAML schema (called automatically in setup())
databricks.yaml.inject()

-- Spark type stubs (called automatically in setup())
databricks.python.inject()

-- Refresh vim.g state
databricks.refresh()
```
