local utils = require("databricks._commands.utils")
local logfile = require("databricks._commands.run.log")
local verbose_config = require("databricks.config").config.verbose

local M = {}

function M.log(msg)
  logfile.log(msg)
end

function M.write(msg)
  logfile.write(msg)
end

function M.error(msg)
  logfile.error(msg)
end

---@param s string
---@return string
function M.json_escape(s)
  return s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
end

local function parse_json(raw)
  local trimmed = raw:gsub("%s+$", "")
  local ok, data = pcall(vim.json.decode, trimmed)
  if ok and data then
    return data, nil
  end

  local start_pos = trimmed:find("{")
  if not start_pos then
    return nil, "no JSON object found in response"
  end

  local depth = 0
  local end_pos = nil
  for i = start_pos, #trimmed do
    local c = trimmed:sub(i, i)
    if c == "{" then
      depth = depth + 1
    elseif c == "}" then
      depth = depth - 1
      if depth == 0 then
        end_pos = i
        break
      end
    end
  end

  if not end_pos then
    return nil, "unterminated JSON object in response"
  end

  local json_str = trimmed:sub(start_pos, end_pos)
  ok, data = pcall(vim.json.decode, json_str)
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
