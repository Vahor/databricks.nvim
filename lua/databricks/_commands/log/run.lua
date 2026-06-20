local logfile = require("databricks._commands.run.log")

local M = {}

function M.parse()
  return {}
end

--- List or open past run log files.
function M.run(opts)
  local logs = logfile.list_logs()
  if #logs == 0 then
    vim.notify("databricks.nvim: no run logs found", vim.log.levels.INFO)
    return
  end

  vim.ui.select(logs, {
    prompt = "Databricks run logs",
    format_item = function(item)
      return item.display
    end,
  }, function(choice)
    print("choice:", choice.path, choice.label)
    if choice then
      logfile.open_log(choice)
    end
  end)
end

function M.help()
  return "log  List log files"
end

return M
