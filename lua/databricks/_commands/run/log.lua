local M = {}
local utils = require("databricks._commands.utils")

local LOG_DIR = vim.fn.stdpath("data") .. "/databricks.nvim"

local DIM = "\x1b[2m"
local RESET = "\x1b[0m"
local RED = "\x1b[31m"
local CYAN = "\x1b[36m"

local current = nil

function M.init()
  vim.fn.mkdir(LOG_DIR, "p")
end

function M.start_run(language, profile, source, log_name)
  M.init()
  local ts = os.date("%Y-%m-%d-%H-%M-%S")
  local safe_source = (source or "unknown"):gsub("[^%w%.%-]", "_")
  local name = type(log_name) == "string" and log_name or safe_source
  local path = LOG_DIR .. "/" .. name .. ".log"
  local f, err = io.open(path, "w")
  if not f then
    vim.notify("databricks.nvim: cannot create log file: " .. (err or "unknown"), vim.log.levels.ERROR)
    return nil
  end
  f:write(DIM .. "# " .. ts .. " | " .. (profile or "default") .. " | " .. language .. RESET .. "\n")
  f:flush()
  current = { path = path, file = f, ts = ts }
  return path
end

function M.log(msg)
  if current and current.file then
    current.file:write(DIM .. "# " .. msg .. RESET)
    current.file:flush()
  end
end

function M.write(msg)
  if current and current.file then
    current.file:write(msg)
    current.file:flush()
  end
end

function M.error(msg)
  if current and current.file then
    current.file:write(RED .. msg .. RESET)
    current.file:flush()
  end
end

function M.close_run()
  if current and current.file then
    current.file:close()
    current = nil
  end
end

function M.current_path()
  if current then
    return current.path
  end
  return nil
end

local function log_name(path)
  local name = path:match("/(.+)%.log$")
  if name then
    return name
  end
  return path
end

function M.list_logs()
  M.init()
  local logs = {}
  local dirs = vim.fn.readdir(LOG_DIR)
  for _, entry in ipairs(dirs) do
    local path = LOG_DIR .. "/" .. entry
    if entry:match("%.log$") then
      local stat = vim.uv.fs_stat(path)
      if stat then
        table.insert(logs, {
          name = entry,
          path = path,
          mtime = stat.mtime.sec,
          label = log_name(entry),
        })
      end
    end
  end
  table.sort(logs, function(a, b)
    return a.mtime > b.mtime
  end)
  return logs
end

function M.open_log(name)
  local logs = M.list_logs()
  local target = nil
  for _, log in ipairs(logs) do
    if log.name == name or log.label == name then
      target = log
      break
    end
  end
  if not target then
    vim.notify("databricks.nvim: log '" .. name .. "' not found", vim.log.levels.ERROR)
    return
  end
  local buf = vim.fn.bufnr(target.path)
  if buf == -1 then
    local win
    buf, win = utils.ensure_buffer_window(target.path, {
      reuse = false,
      filetype = "log",
      style = false,
    })
    local lines = {}
    for line in io.lines(target.path) do
      table.insert(lines, line)
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(win, { #lines, 0 })
  else
    local _, win = utils.ensure_buffer_window(target.path, {
      reuse = true,
      style = false,
    })
    vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
  end
end

function M.cleanup(max_count)
  max_count = max_count or 10
  local logs = M.list_logs()
  if #logs > max_count then
    for i = max_count + 1, #logs do
      os.remove(logs[i].path)
    end
  end
end

return M
