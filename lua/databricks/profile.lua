local config = require("databricks.config")

local M = {}

--- Resolve a config value that can be a string, a function, or nil (with env var fallback).
--- @param value string|fun():string|nil
--- @param env_var string Environment variable name to check as fallback
--- @return string|nil
function M._resolve(value, env_var)
  if type(value) == "function" then
    return value()
  end
  local from_env = vim.env[env_var]
  if from_env and from_env ~= "" then
    return from_env
  end
  if type(value) == "string" then
    return value
  end
  return nil
end

--- Resolve the active profile.
--- @return string|nil
function M.resolve()
  return M._resolve(config.config.profile, "DATABRICKS_PROFILE")
end

return M
