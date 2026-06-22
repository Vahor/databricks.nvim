local M = {}
local utils = require("databricks._commands.utils")
local config = require("databricks.config")
local dab = require("databricks.dab")

local function get_root_dir()
  local root = dab.find_root()
  return root or vim.fn.getcwd()
end

local function get_log_dir()
  local base = config.config.log.dir
  local root = get_root_dir()
  local subdir = vim.fn.fnamemodify(root, ":t")
  return base .. "/" .. subdir
end

local DIM = "\x1b[2m"
local RESET = "\x1b[0m"
local RED = "\x1b[31m"
local CYAN = "\x1b[36m"

--- Active runs keyed by log path. Multiple concurrent runs can write to
--- separate log files without stepping on each other.
---@type table<string, {file: file*}>"
local runs = {}

function M.init()
  vim.fn.mkdir(get_log_dir(), "p")
end

function M.start_run(profile, source, log_name)
  M.init()
  local ts = os.date("%Y-%m-%dT%H:%M:%S")
  local safe_source = (source or "unknown"):gsub("[^%w%.%-]", "_")
  local name = type(log_name) == "string" and log_name or safe_source
  local path = get_log_dir() .. "/" .. name .. ".log"
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
  runs[path] = { file = f }
  return path
end

---@param path string
---@return file*|nil
local function _file(path)
  local run = runs[path]
  return run and run.file
end

--- Write a dimmed log comment line.
---@param msg string
---@param path string  Run path from start_run.
function M.log(msg, path)
  local f = _file(path)
  if f then
    f:write(DIM .. "# " .. msg .. RESET)
    f:flush()
  end
end

--- Write raw output (unstyled).
---@param msg string
---@param path string
function M.write(msg, path)
  local f = _file(path)
  if f then
    f:write(msg)
    f:flush()
  end
end

--- Write an error line in red.
---@param msg string
---@param path string
function M.error(msg, path)
  local f = _file(path)
  if f then
    f:write(RED .. msg .. RESET)
    f:flush()
  end
end

--- Close the run's file handle and clean up state.
---@param path string
function M.close_run(path)
  local run = runs[path]
  if run and run.file then
    run.file:close()
  end
  runs[path] = nil
end

local function log_name(path)
  local name = path:match("/(.+)%.log$")
  if name then
    return name
  end
  return path
end

local function revert_clean_name(name)
  name = name:gsub("__", "\1")
  name = name:gsub("_", "/")
  name = name:gsub("\1", "_")
  return name
end

local function strip_log_ext(path)
  return path:gsub("%.log$", "")
end

function M.list_logs()
  M.init()
  local log_dir = get_log_dir()
  local root = get_root_dir()
  local logs = {}
  local dirs = vim.fn.readdir(log_dir)
  for _, entry in ipairs(dirs) do
    local path = log_dir .. "/" .. entry
    if entry:match("%.log$") then
      local stat = vim.uv.fs_stat(path)
      if stat then
        local ts = os.date("%Y-%m-%d %H:%M:%S", stat.mtime.sec)
        local label = log_name(entry)
        local shown = revert_clean_name(label)
        table.insert(logs, {
          name = entry,
          path = path,
          mtime = stat.mtime.sec,
          display = string.format("%s  %s", shown, ts),
          file = strip_log_ext(label),
          file_path = root .. "/" .. strip_log_ext(shown),
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
