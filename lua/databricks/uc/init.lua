local config = require("databricks.config")
local utils = require("databricks._commands.utils")

--- @class Databricks.UCCache
--- @field tables table<string, { comment: string|nil, columns: table<string, { type: string, comment: string|nil }> }>

local M = {}

local cache_path = vim.fn.stdpath("data") .. "/databricks.nvim/uc_cache.json"

--- @type Databricks.UCCache
local cache = {}

--- @return Databricks.UCCache
local function default_cache()
  return { tables = {} }
end

--- @private
local function glob_match(s, pattern)
  local lua_pattern = "^" .. pattern:gsub("%.", "%%."):gsub("%*", ".*"):gsub("%?", ".") .. "$"
  return s:lower():match(lua_pattern) ~= nil
end

--- Apply catalog/schema filtering to a list of names.
--- Each filter entry can be an exact name or a glob pattern (supports * and ?).
---@param names string[]
---@param config_key string config key (e.g. "catalogs")
---@param env_var string env var (e.g. "DATABRICKS_UC_CATALOGS")
---@return string[]
local function apply_filter(names, config_key, env_var)
  local cfg = config.config.completion and config.config.completion.uc
  if not cfg then
    return names
  end
  local filter = utils.resolve_array(cfg[config_key], env_var)
  if not filter then
    return names
  end
  local result = {}
  for _, name in ipairs(names) do
    for _, pattern in ipairs(filter) do
      if glob_match(name, pattern) then
        table.insert(result, name)
        break
      end
    end
  end
  return result
end

--- @private
local function parse_tables(tables_data)
  for _, tbl in ipairs(tables_data) do
    local full_name = tbl.full_name
    if full_name then
      local entry = { comment = tbl.comment, columns = {} }
      if tbl.columns then
        for _, col in ipairs(tbl.columns) do
          entry.columns[col.name] = { type = col.type_name or col.type_text or "unknown", comment = col.comment }
        end
      end
      cache.tables[full_name] = entry
    end
  end
end

--- Fetch all UC metadata from Databricks CLI.
--- Populates the in-memory cache and saves to disk.
---@return boolean true if at least some data was fetched
function M.fetch_all()
  cache = default_cache()

  local cat_data = utils.databricks_cmd_json({ "catalogs", "list" })
  if not cat_data then
    return false
  end

  local all_catalogs = {}
  for _, cat in ipairs(cat_data) do
    table.insert(all_catalogs, cat.name or cat.full_name)
  end

  local catalogs = apply_filter(all_catalogs, "catalogs", "DATABRICKS_NVIM_UC_CATALOGS")

  for _, cat_name in ipairs(catalogs) do
    local schema_data = utils.databricks_cmd_json({ "schemas", "list", cat_name })
    if not schema_data then
      -- skip this catalog
    else
      local schema_names = {}
      for _, s in ipairs(schema_data) do
        if s.full_name then
          table.insert(schema_names, s.full_name)
        end
      end

      local filtered = apply_filter(schema_names, "schemas", "DATABRICKS_NVIM_UC_SCHEMAS")
      for _, schema_full in ipairs(filtered) do
        local schema_name = schema_full:match("^[^%.]+%.(.+)$")
        if schema_name then
          local tables_data = utils.databricks_cmd_json({
            "tables",
            "list",
            cat_name,
            schema_name,
            "--omit-properties",
            "--omit-username",
          })
          if tables_data then
            parse_tables(tables_data)
          end
        end
      end
    end
  end

  M.save()
  return true
end

--- Load cache from disk.
---@return boolean true if cache was loaded
function M.load()
  local f = io.open(cache_path, "r")
  if not f then
    return false
  end
  local content = f:read("*a")
  f:close()
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" or not decoded.tables then
    return false
  end
  cache = decoded
  return true
end

--- Save in-memory cache to disk.
function M.save()
  local dir = vim.fn.stdpath("data") .. "/databricks.nvim"
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  local f = io.open(cache_path, "w")
  if f then
    f:write(vim.json.encode(cache))
    f:close()
  end
end

--- Ensure cache is populated (disk read only, never blocks on CLI).
--- Call refresh() explicitly to fetch fresh data from the API.
function M.ensure()
  if cache.tables and next(cache.tables) then
    return
  end
  M.load()
end

--- Invalidate in-memory cache and re-fetch from CLI.
function M.refresh()
  cache = default_cache()
  M.fetch_all()
end

--- Get all catalog names from the cache.
---@return string[]
function M.get_catalogs()
  local catalogs = {}
  local seen = {}
  for full_name in pairs(cache.tables) do
    local cat = full_name:match("^([^%.]+)")
    if cat and not seen[cat] then
      seen[cat] = true
      table.insert(catalogs, cat)
    end
  end
  table.sort(catalogs)
  return catalogs
end

--- Get all schema full names from the cache.
---@return string[]
function M.get_schemas()
  local schemas = {}
  local seen = {}
  for full_name in pairs(cache.tables) do
    local schema = full_name:match("^([^%.]+%.[^%.]+)")
    if schema and not seen[schema] then
      seen[schema] = true
      table.insert(schemas, schema)
    end
  end
  table.sort(schemas)
  return schemas
end

--- Get all table full names from the cache.
---@return string[]
function M.get_tables()
  local names = {}
  for full_name in pairs(cache.tables) do
    table.insert(names, full_name)
  end
  table.sort(names)
  return names
end

--- Get column names for a table.
---@param full_table string catalog.schema.table
---@return table<string, { type: string, comment: string|nil }>
function M.get_columns(full_table)
  local entry = cache.tables[full_table]
  if not entry then
    return {}
  end
  return entry.columns
end

--- Get table comment.
---@param full_table string catalog.schema.table
---@return string|nil
function M.get_comment(full_table)
  local entry = cache.tables[full_table]
  if not entry then
    return nil
  end
  return entry.comment
end

--- Check if cache is populated.
---@return boolean
function M.is_loaded()
  return cache.tables and next(cache.tables) ~= nil
end

--- Get tables that belong to a schema.
---@param schema string catalog.schema
---@return string[]
function M.get_tables_for_schema(schema)
  local prefix = schema .. "."
  local names = {}
  for full_name in pairs(cache.tables) do
    if vim.startswith(full_name, prefix) then
      table.insert(names, full_name)
    end
  end
  table.sort(names)
  return names
end

return M
