local logfile = require("databricks._commands.run.log")
local config = require("databricks.config")

local M = {}

---@param args string[]
---@return table|nil
function M.parse(args)
  local opts = {}
  local i = 1

  while i <= #args do
    local arg = args[i]
    if arg == "--open" then
      opts.open = true
    elseif arg == "--no-open" then
      opts.open = false
    else
      vim.notify("databricks.nvim: unknown flag '" .. arg .. "'", vim.log.levels.ERROR)
      return nil
    end
    i = i + 1
  end

  return opts
end

--- List or open past run log files.
function M.run(opts)
  local logs = logfile.list_logs()
  if #logs == 0 then
    vim.notify("databricks.nvim: no run logs found", vim.log.levels.INFO)
    return
  end

  local ok, telescope_picker = pcall(require, "databricks._commands.log.telescope")
  if not ok then
    vim.notify("databricks.nvim: telescope.nvim is required for log picker", vim.log.levels.ERROR)
    return
  end
  telescope_picker.pick(logs, { open = opts.open })
end

function M.help()
  return "log [--open]  List log files"
end

return M
