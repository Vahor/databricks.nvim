local config = require("databricks.config")
local utils = require("databricks._commands.utils")

local M = {}

function M.resolve()
  return utils.resolve(config.config.profile, "DATABRICKS_PROFILE")
end

return M
