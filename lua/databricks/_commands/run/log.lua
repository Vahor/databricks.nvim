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

function M.start_run(profile, source, log_name)
  M.init()
  local ts = os.date("%Y-%m-%dT%H:%M:%S")
  local safe_source = (source or "unknown"):gsub("[^%w%.%-]", "_")
  local name = type(log_name) == "string" and log_name or safe_source
  local path = LOG_DIR .. "/" .. name .. ".log"
  local f, err = io.open(path, "a+")
  if not f then
    vim.notify("databricks.nvim: cannot create log file: " .. (err or "unknown"), vim.log.levels.ERROR)
    return nil
  end

  local stat = vim.uv.fs_stat(path)
  local is_empty = stat and stat.size == 0
  if not is_empty then
    f:write("\n\n")
  end

  f:write(DIM .. "# " .. ts .. " | " .. (profile or "default") .. " | " .. (source or "unknown") .. RESET .. "\n\n")
  f:flush()
  current = { path = path, file = f }
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

local function strip_log_ext(path)
  return path:gsub("%.log$", "")
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
        local ts = os.date("%Y-%m-%d %H:%M:%S", stat.mtime.sec)
        local label = log_name(entry)
        table.insert(logs, {
          name = entry,
          path = path,
          mtime = stat.mtime.sec,
          display = string.format("%s  %s", label, ts),
          file = strip_log_ext(label),
        })
      end
    end
  end
  table.sort(logs, function(a, b)
    return a.mtime > b.mtime
  end)
  return logs
end

---@param log{path: string, file: string}
function M.open_log(log)
  return utils.run_terminal_tail(log.path, { name = log.file })
end

return M
