local bundle_cache = require("databricks._commands.bundle_cache")
local dab = require("databricks.dab")
local profile = require("databricks.profile")
local utils = require("databricks._commands.utils")

local M = {}

M.accepts_target = true

local function resolve_templates(str, data)
  return str:gsub("%${([^}]+)}", function(path)
    local current = data
    for _, part in ipairs(vim.split(path, "%.")) do
      if type(current) ~= "table" then
        return "${" .. path .. "}"
      end
      current = current[part]
    end
    return current ~= nil and tostring(current) or "${" .. path .. "}"
  end)
end

local function get_in(data, ...)
  for _, key in ipairs({ ... }) do
    if type(data) ~= "table" then
      return nil
    end
    data = data[key]
  end
  return data
end

local default_variables = {
  {
    name = "bundle.name",
    description = "The name of the bundle",
    resolve = function(data)
      return get_in(data, "bundle", "name")
    end,
  },
  {
    name = "bundle.target",
    description = "The current target (e.g. dev, prod)",
    resolve = function(data)
      return get_in(data, "bundle", "target")
    end,
  },
  {
    name = "workspace.current_user.userName",
    description = "Email of the current user",
    resolve = function(data)
      return get_in(data, "workspace", "current_user", "userName")
    end,
  },
  {
    name = "workspace.current_user.short_name",
    description = "Short name of the current user",
    resolve = function(data)
      return get_in(data, "workspace", "current_user", "short_name")
    end,
  },
  {
    name = "workspace.file_path",
    description = "Remote workspace path for deployment",
    resolve = function(data)
      return get_in(data, "workspace", "file_path")
    end,
  },
  {
    name = "workspace.host",
    description = "Databricks workspace host URL",
    resolve = function()
      return profile.resolve_host()
    end,
  },
}

---@param args string[]
---@return table|nil
function M.parse(args)
  return utils.parse_bundle_flags(args)
end

function M.run(opts)
  if not dab.is_dab_project() then
    vim.notify("databricks.nvim: not in a DAB project", vim.log.levels.ERROR)
    return
  end
  local root = dab.find_root()
  if not root then
    return
  end

  bundle_cache.loading = true
  local data = bundle_cache.summary({
    root = root,
    target = opts.target,
    refresh = opts.refresh,
  })
  bundle_cache.loading = false
  if not data then
    return
  end

  local files = dab.get_bundle_files(root)
  local yaml_defs = dab.find_variable_definitions(files)

  local entries = {}
  if data.variables then
    for name, vv in pairs(data.variables) do
      local def = yaml_defs[name] or {}
      table.insert(entries, {
        name = name,
        value = vv.value,
        default = vv.default,
        lookup = vv.lookup,
        description = vv.description or "",
        vtype = vv.type or (vv.lookup and "lookup" or "unknown"),
        source = {
          path = def.path,
          line = def.line,
        },
      })
    end
  end

  for _, dv in ipairs(default_variables) do
    if not yaml_defs[dv.name] then
      table.insert(entries, {
        name = dv.name,
        description = dv.description,
        vtype = "built-in",
        value = dv.resolve and dv.resolve(data),
        readonly = true,
      })
    end
  end

  for _, entry in ipairs(entries) do
    local val = entry.value or entry.default
    if type(val) == "string" and val:find("%${") then
      entry.resolved = resolve_templates(val, data)
    end
  end

  table.sort(entries, function(a, b)
    return a.name < b.name
  end)

  local ok_tel, telescope_picker = pcall(require, "databricks._commands.variables.telescope")
  if not ok_tel then
    vim.notify("databricks.nvim: telescope.nvim is required", vim.log.levels.ERROR)
    return
  end

  telescope_picker.pick(entries)
end

function M.help()
  return "variables [--target <name>] [--refresh]  Browse DAB variables"
end

return M
