local config = require("databricks.config")
local utils = require("databricks._commands.utils")

local M = {}

--- Cache for resolved hosts, keyed by profile name.
local host_cache = {}

--- Resolve the active Databricks CLI profile.
--- Checks, in order: config function, env var DATABRICKS_PROFILE, config string.
---@return string|nil
function M.resolve()
  return utils.resolve(config.config.profile, "DATABRICKS_PROFILE")
end

---@private
local function parse_host(res, env_host)
  local result
  if res and res.code == 0 then
    local decode_ok, data = pcall(vim.json.decode, res.stdout)
    if decode_ok and type(data) == "table" then
      local host = data.details and data.details.configuration and data.details.configuration.host
      if host and host.value and host.value ~= "" then
        result = host.value
      end
    end
  end

  if not result and env_host and env_host ~= "" then
    result = env_host
  end

  return result
end

--- Resolve the Databricks workspace host URL for the current profile.
--- Uses `databricks auth describe --output json`, falls back to $DATABRICKS_HOST.
--- Result is cached per profile.
---@param async boolean|nil When true, spawn without blocking and cache later.
---@return string|nil
function M.resolve_host(async)
  local profile = M.resolve() or "DEFAULT"
  if host_cache[profile] ~= nil then
    return host_cache[profile]
  end

  local cmd = utils.databricks_cmd({ "auth", "describe", "--output", "json" })

  local env_host = vim.env.DATABRICKS_HOST

  if async then
    local ok, handle = pcall(vim.system, cmd, { text = true, env = utils.build_env() }, function(res)
      host_cache[profile] = parse_host(res, env_host)
    end)
    if not ok then
      host_cache[profile] = parse_host(nil, env_host)
    end
    return nil
  end

  local ok, handle = pcall(vim.system, cmd, { text = true, env = utils.build_env() })
  if not ok then
    host_cache[profile] = parse_host(nil, env_host)
    return host_cache[profile]
  end

  local res = handle:wait()
  host_cache[profile] = parse_host(res, env_host)
  return host_cache[profile]
end

--- Check whether Databricks authentication is valid.
--- Runs `databricks auth describe --output json` and checks exit code.
---@return boolean
function M.check()
  local cmd = utils.databricks_cmd({ "auth", "describe", "--output", "json" })
  local ok, handle = pcall(vim.system, cmd, { text = true, env = utils.build_env() })
  if not ok then
    return false
  end
  local res = handle:wait()
  return res.code == 0
end

return M
