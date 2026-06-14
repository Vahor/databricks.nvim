--- Parser for the `:Databricks deploy` subcommand.

local M = {}

---@param args string[] Remaining arguments after the subcommand name
---@return table Parsed options table (currently empty, ready for future flags)
function M.parse(args)
  return {}
end

---@return string
function M.help()
  return "deploy  Run `databricks bundle deploy` in a terminal split"
end

return M
