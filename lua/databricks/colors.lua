--- ANSI escape codes for terminal output.
--- Used by build_term_command for the header line in terminal splits.

local M = {}

M.dim = "\x1b[2m"
M.reset = "\x1b[0m"
M.cyan = "\x1b[36m"

--- Wrap text in dim (gray) escape codes.
function M.gray(text)
  return M.dim .. text .. M.reset
end

return M
