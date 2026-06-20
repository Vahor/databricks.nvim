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

--- Resolve the Databricks workspace host URL for the current profile.
--- Uses `databricks auth describe --output json`, falls back to $DATABRICKS_HOST.
--- Result is cached per profile.
---@return string|nil
function M.resolve_host()
  local profile = M.resolve() or "DEFAULT"
  if host_cache[profile] ~= nil then
    return host_cache[profile]
  end

  local result
  local cmd = utils.databricks_cmd({ "auth", "describe", "--output", "json" })
  local ok, handle = pcall(vim.system, cmd, { text = true, env = utils.build_env() })
  if ok then
    local res = handle:wait()
    if res.code == 0 then
      local decode_ok, data = pcall(vim.json.decode, res.stdout)
      if decode_ok and type(data) == "table" then
        local host = data.details and data.details.configuration and data.details.configuration.host
        if host and host.value and host.value ~= "" then
          result = host.value
        end
      end
    end
  end

  if not result then
    local env_host = vim.env.DATABRICKS_HOST
    if env_host and env_host ~= "" then
      result = env_host
    end
  end

  host_cache[profile] = result
  return result
end

return M
