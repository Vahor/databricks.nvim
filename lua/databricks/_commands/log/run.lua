local logfile = require("databricks._commands.run.log")

local M = {}

function M.parse()
  return {}
end

--- List or open past run log files.
function M.run(_opts)
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
  telescope_picker.pick(logs)
end

function M.help()
  return "log  List log files"
end

return M
