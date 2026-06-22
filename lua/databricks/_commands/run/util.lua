local utils = require("databricks._commands.utils")
local logfile = require("databricks._commands.run.log")
local verbose_config = require("databricks.config").config.verbose

local M = {}

--- Log path set by run.run before invoking python/sql/cluster runners.
---@type string|nil
local _log_path = nil

--- Set the log path for the current run.
---@param path string
function M.set_log_path(path)
  _log_path = path
end

---@param msg string
function M.log(msg)
  logfile.log(msg, _log_path)
end

---@param msg string
function M.write(msg)
  logfile.write(msg, _log_path)
end

---@param msg string
function M.error(msg)
  logfile.error(msg, _log_path)
end

function M.close_run()
  logfile.close_run(_log_path)
  _log_path = nil
end

--- Strip any text before the first `{` so the CLI's log output does not
--- interfere with JSON decoding.
local function parse_json(raw)
  local json_str = raw:gsub("^[^{]*", "", 1)
  local ok, data = pcall(vim.json.decode, json_str)
  if ok and data then
    return data, nil
  end
  return nil, "failed to parse JSON from response"
end

--- vim.system callbacks may run in fast context; schedule to main loop
--- so vim.api calls inside on_ok/on_err are safe.
---@param api_args string[]
---@param on_ok fun(data: table)
---@param on_err fun(msg: string)
function M.api_call(api_args, on_ok, on_err)
  local cmd = utils.databricks_cmd(api_args)

  if verbose_config then
    logfile.log("[verbose] " .. table.concat(cmd, " ") .. "\n")
  end

  vim.system(cmd, { text = true, env = utils.build_env() }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        on_err(result.stderr or "unknown error")
        return
      end

      local data, err = parse_json(result.stdout)
      if not data then
        on_err(err or result.stdout)
        return
      end

      on_ok(data)
    end)
  end)
end

return M
