local logfile = require("databricks._commands.run.log")

local M = {}

--- Parse CLI args for `:Databricks log`.
--- No args → list mode; with name → open mode.
---@param args string[]
---@return {mode: "list"|"open", name: string|nil}
function M.parse(args)
  return { mode = args[1] and "open" or "list", name = args[1] }
end

--- List or open past run log files.
---@param opts {mode: "list"|"open", name: string|nil}
function M.run(opts)
  if opts.mode == "list" then
    local logs = logfile.list_logs()
    if #logs == 0 then
      vim.notify("databricks.nvim: no run logs found", vim.log.levels.INFO)
      return
    end
    local lines = { "Databricks run logs:" }
    for _, log in ipairs(logs) do
      local ts = os.date("%Y-%m-%d %H:%M:%S", log.mtime)
      table.insert(lines, string.format("  %s  %s", ts, log.name))
    end
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
    return
  end

  logfile.open_log(opts.name)
end

function M.help()
  return "log [name]  List or view past run log files"
end

return M
