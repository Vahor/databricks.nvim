## Lua API

```lua
local databricks = require("databricks")

-- DAB detection
databricks.dab.is_dab_project()   --> boolean
databricks.dab.find_root()        --> string | nil
databricks.dab.is_dab_root(path)  --> boolean

-- Profile
databricks.profile.resolve()      --> string | nil

-- Schema (called automatically in setup())
databricks.schema.inject()

-- Spark (called automatically in setup())
databricks.spark.inject()

-- Refresh vim.g state
databricks.refresh()
```
