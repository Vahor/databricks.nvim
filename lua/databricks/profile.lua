local config = require("databricks.config")

local M = {}

--- Resolve the active profile.
--- @return string|nil
function M.resolve()
  if config.config.profile then
    return config.config.profile
  end

  return nil
end

return M
