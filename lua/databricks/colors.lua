--- ANSI escape codes for terminal output colors.
--- Usage: local C = require("databricks.colors")
---   text = C.gray("gray text")
---   text = C.dim .. "gray" .. C.reset

local M = {}

M.dim = "\x1b[2m"
M.reset = "\x1b[0m"
M.cyan = "\x1b[36m"

--- Wrap text in dim (gray) escape codes.
function M.gray(text)
  return M.dim .. text .. M.reset
end

return M
