--- Parser for the `:Databricks deploy` subcommand.

local M = {}

---@class Databricks.DeployOpts
---@field force boolean
---@field auto_approve boolean
---@field target string|nil

--- Parse CLI arguments for `:Databricks deploy`.
--- Supported flags: --force, --auto-approve, --target <name>
---@param args string[] Remaining arguments after the subcommand name
---@return Databricks.DeployOpts Parsed options table
function M.parse(args)
  local opts = { force = false, auto_approve = false, target = nil }
  local i = 1

  while i <= #args do
    local arg = args[i]
    if arg == "--force" then
      opts.force = true
    elseif arg == "--auto-approve" then
      opts.auto_approve = true
    elseif arg == "--target" then
      i = i + 1
      local val = args[i]
      if not val or vim.startswith(val, "-") then
        vim.notify("databricks.nvim: --target requires a value", vim.log.levels.ERROR)
        return nil
      end
      opts.target = val
    else
      vim.notify("databricks.nvim: unknown flag '" .. arg .. "'", vim.log.levels.ERROR)
      return nil
    end
    i = i + 1
  end

  return opts
end

---@return string
function M.help()
  return "deploy [--force] [--auto-approve] [--target <name>]  Run `databricks bundle deploy` in a terminal split"
end

return M
