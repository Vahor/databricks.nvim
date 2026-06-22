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

--- Counter for generating unique run IDs.
local run_counter = 0

--- Active runs keyed by unique run ID. Multiple concurrent runs can write to
--- separate log files (or even the same file) without stepping on each other.
---@type table<string, {file: file*, path: string}>
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

  run_counter = run_counter + 1
  local run_id = "run_" .. run_counter
  runs[run_id] = { file = f, path = path }
  return run_id
end

---@param run_id string
---@return file*|nil
local function _file(run_id)
  local run = runs[run_id]
  return run and run.file
end

--- Get the log file path for a run ID.
---@param run_id string
---@return string|nil
function M.get_path(run_id)
  local run = runs[run_id]
  return run and run.path
end

--- Write a dimmed log comment line.
---@param msg string
---@param run_id string  Run ID from start_run.
function M.log(msg, run_id)
  local f = _file(run_id)
  if f then
    f:write(DIM .. "# " .. msg .. RESET)
    f:flush()
  end
end

--- Write raw output (unstyled).
---@param msg string
---@param run_id string
function M.write(msg, run_id)
  local f = _file(run_id)
  if f then
    f:write(msg)
    f:flush()
  end
end

--- Write an error line in red.
---@param msg string
---@param run_id string
function M.error(msg, run_id)
  local f = _file(run_id)
  if f then
    f:write(RED .. msg .. RESET)
    f:flush()
  end
end

--- Close the run's file handle and clean up state.
---@param run_id string
function M.close_run(run_id)
  if not run_id then
    return
  end
  local run = runs[run_id]
  if run and run.file then
    run.file:close()
  end
  runs[run_id] = nil
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
