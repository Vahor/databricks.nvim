local config = require("databricks.config")

local M = {}

local function resolve(value, env_var)
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

function M.resolve()
  return resolve(config.config.profile, "DATABRICKS_PROFILE")
end

return M
