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

-- Unity Catalog cache
databricks.uc.ensure()       --> Load from disk or fetch from CLI
databricks.uc.refresh()      --> Re-fetch all metadata from CLI
databricks.uc.get_catalogs() --> string[]
databricks.uc.get_schemas()  --> string[]
databricks.uc.get_tables()   --> string[]
databricks.uc.get_columns(full_table_name) --> table<name, {type, comment}>
```
