--- Shared helpers for run sub-commands.

local utils = require("databricks._commands.utils")

local M = {}

local BUF_NAME = "Run"
local ansi_esc = string.char(27)

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

--- Append an error message (red).
function M.error(msg)
  utils.append_to_buffer(BUF_NAME, msg, "ErrorMsg")
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

--- Strip ANSI escape sequences from a string.
---@param s string
---@return string
local function strip_ansi(s)
  -- walk byte by byte: skip ESC[...letter sequences and bare [...letter
  local result = {}
  local i = 1
  while i <= #s do
    local b = s:byte(i)
    if b == 27 then -- ESC
      i = i + 1 -- skip ESC
    elseif b == 91 then -- '[' (start of CSI, with or without preceding ESC)
      -- Only treat as CSI if the next byte is a digit or ';'
      local next_byte = i + 1 <= #s and s:byte(i + 1)
      if not next_byte or not ((next_byte >= 48 and next_byte <= 57) or next_byte == 59) then
        table.insert(result, "[")
        i = i + 1
      else
        local j = i + 1
        while j <= #s do
          local cb = s:byte(j)
          if (cb >= 65 and cb <= 90) or (cb >= 97 and cb <= 122) then -- any ANSI terminator letter
            i = j + 1
            break
          elseif (cb >= 48 and cb <= 57) or cb == 59 then -- digit or ';'
            j = j + 1
          else
            -- not a CSI sequence, keep the '['
            table.insert(result, "[")
            i = i + 1
            break
          end
        end
        if j > #s then -- unterminated, keep as-is
          table.insert(result, s:sub(i))
          break
        end
      end
    else
      table.insert(result, s:sub(i, i))
      i = i + 1
    end
  end
  return table.concat(result)
end

--- Try to parse JSON from a string, falling back to extracting the first {...} block.
---@param raw string
---@return table|nil data, string|nil error_message
local function parse_json(raw)
  local trimmed = raw:gsub("%s+$", "")
  local ok, data = pcall(vim.json.decode, trimmed)
  if ok and data then
    return data, nil
  end
  -- CLI may have emitted extra output before/after the JSON body.
  -- Try to find and parse the first {...} block.
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
    -- vim.system callbacks may run in fast context; schedule to main loop
    -- so vim.fn calls inside on_ok/on_err (timer_stop, etc.) are safe.
    vim.schedule(function()
      if result.code ~= 0 then
        on_err(strip_ansi(result.stderr or "unknown error"))
        return
      end
      local data, err = parse_json(result.stdout)
      if not data then
        on_err(strip_ansi(err or result.stdout))
        return
      end
      on_ok(data)
    end)
  end)
end

return M
