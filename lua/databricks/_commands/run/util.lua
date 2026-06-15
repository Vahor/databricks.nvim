--- Shared helpers for run sub-commands.

local utils = require("databricks._commands.utils")

local M = {}

local BUF_NAME = "Run"

--- Get the verbose setting.
local function verbose()
  return require("databricks.config").config.verbose
end

--- Append a status/log message (gray).
function M.log(msg)
  utils.append_to_buffer(BUF_NAME, msg, "Comment")
end

--- Append output data (normal color).
function M.write(msg)
  utils.append_to_buffer(BUF_NAME, msg)
end

--- Set the global run state for lualine consumers.
---@param state "idle" | "running" | "error"
function M.set_state(state)
  vim.g.databricks_run_state = state
end

--- Escape a string for safe inclusion in a JSON string value.
---@param s string
---@return string
function M.json_escape(s)
  return s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
end

--- Run a `databricks api` command and call on_ok with parsed JSON, or on_err with message.
---@param api_args string[] Arguments after `databricks api` (e.g. {"get", "/..."})
---@param on_ok fun(data: table)
---@param on_err fun(msg: string)
function M.api_call(api_args, on_ok, on_err)
  local cmd = utils.databricks_cmd(api_args)
  if verbose() then
    utils.append_to_buffer(BUF_NAME, "  [verbose] " .. table.concat(cmd, " ") .. "\n", "Comment")
  end
  vim.system(cmd, { text = true, env = utils.build_env() }, function(result)
    if result.code ~= 0 then
      on_err(result.stderr or "unknown error")
      return
    end
    local ok, data = pcall(vim.json.decode, result.stdout:gsub("%s+$", ""))
    if not ok or not data then
      on_err(result.stdout)
      return
    end
    on_ok(data)
  end)
end

return M
