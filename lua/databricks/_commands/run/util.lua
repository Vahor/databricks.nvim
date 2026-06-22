local utils = require("databricks._commands.utils")
local logfile = require("databricks._commands.run.log")
local verbose_config = require("databricks.config").config.verbose

local M = {}

--- Run ID set by run.run before invoking python/sql/cluster runners.
---@type string|nil
local _run_id = nil

--- Set the run ID for the current run.
---@param run_id string
function M.set_run_id(run_id)
  _run_id = run_id
end

---@param msg string
function M.log(msg)
  logfile.log(msg, _run_id)
end

---@param msg string
function M.write(msg)
  logfile.write(msg, _run_id)
end

---@param msg string
function M.error(msg)
  logfile.error(msg, _run_id)
end

function M.close_run()
  logfile.close_run(_run_id)
  _run_id = nil
end

--- Strip any text before the start of JSON so the CLI's log output does not
--- interfere with JSON decoding.
local function parse_json(raw)
  local json_str = raw:gsub('^[^{%["tfn0-9%-]*', "", 1)
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
    M.log("[verbose] " .. table.concat(cmd, " ") .. "\n")
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
