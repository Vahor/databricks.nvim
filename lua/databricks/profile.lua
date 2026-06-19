local config = require("databricks.config")
local utils = require("databricks._commands.utils")

local M = {}

--- Resolve the active Databricks CLI profile.
--- Checks, in order: config function, env var DATABRICKS_PROFILE, config string.
---@return string|nil
function M.resolve()
  return utils.resolve(config.config.profile, "DATABRICKS_PROFILE")
end

return M
