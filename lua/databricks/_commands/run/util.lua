--- Shared helpers for run sub-commands.

local utils = require("databricks._commands.utils")

local M = {}

local BUF_NAME = "Run"

--- Append a message to the run output buffer.
function M.log(msg)
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
---@param cmd string[]
---@param on_ok fun(data: table)
---@param on_err fun(msg: string)
function M.api_call(cmd, on_ok, on_err)
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
