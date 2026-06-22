local config = require("databricks.config")

local M = {}

local open_buffers = {}

local DIM = "\x1b[2m"
local RESET = "\x1b[0m"
local CYAN = "\x1b[36m"

local function style_output_win(win)
  vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"
  vim.wo[win].number = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].statuscolumn = "  "
end

function M.stringify(val)
  if val == nil then
    return "nil"
  end
  if type(val) == "string" then
    return val
  end
  local ok, s = pcall(vim.json.encode, val)
  return ok and s or tostring(val)
end

--- Build a `databricks` CLI command array, prepending `--profile` if a profile is configured.
---
--- For bundle subcommands that accept `--target`, pass an `opts` table to opt in to
--- target handling. The target is resolved like the profile: `opts.target` override
--- first, then the global `target` config (string or function), then the
--- `DATABRICKS_BUNDLE_TARGET` env var. Omit `opts` for commands that don't take
--- `--target`.
---@param args string[]
---@param opts? { target?: string|nil }
---@return string[]
function M.databricks_cmd(args, opts)
  local p = require("databricks.profile").resolve()
  local cmd = { "databricks" }
  if p then
    table.insert(cmd, "--profile")
    table.insert(cmd, p)
  end
  vim.list_extend(cmd, args)
  if opts then
    local target = M.resolve(config.config.target, "DATABRICKS_BUNDLE_TARGET", opts.target)
    if target then
      table.insert(cmd, "--target")
      table.insert(cmd, target)
    end
  end
  return cmd
end

--- Resolve a config value: override > function > string > env var > nil.
---@param value string|(fun():string)|nil
---@param env_var string
---@param override string|nil
---@return string|nil
function M.resolve(value, env_var, override)
  if override ~= nil then
    return override
  end
  if type(value) == "function" then
    return value()
  end
  if type(value) == "string" then
    return value
  end
  local from_env = vim.uv.os_getenv(env_var)
  if from_env and from_env ~= "" then
    return from_env
  end
  return nil
end

--- Reuses the existing resolve() for function/string/env, then splits on comma.
--- Also accepts a literal array table.
---@param value "auto"|string[]|(fun():string)|string|nil
---@param env_var string
---@return string[]|nil
function M.resolve_array(value, env_var)
  if type(value) == "table" then
    return value
  end
  local resolved = M.resolve(value, env_var)
  if not resolved or resolved == "auto" then
    return nil
  end
  local parts = vim.split(resolved, ",")
  for i, part in ipairs(parts) do
    parts[i] = vim.trim(part)
  end
  return parts
end

--- Build environment table with VIRTUAL_ENV and PATH set if a venv is configured.
---@return table<string, string>
function M.build_env()
  local env = {}
  local venv = M.resolve(config.config.venv, "DATABRICKS_NVIM_VENV")
  if venv then
    env["VIRTUAL_ENV"] = venv
    env["PATH"] = venv .. "/bin:" .. (vim.uv.os_getenv("PATH") or "")
  end
  return env
end

--- Run a databricks CLI command and parse the JSON output.
--- Handles --profile and --target automatically.
---@param args string[] CLI arguments
---@param opts? {cwd?: string, target?: string, silent?: boolean, allow_nonzero_json?: boolean}
---@return table|nil Decoded JSON table, or nil on failure
function M.databricks_cmd_json(args, opts)
  opts = opts or {}

  table.insert(args, "--output")
  table.insert(args, "json")

  local cmd = M.databricks_cmd(args, opts.target and { target = opts.target } or nil)
  local sys_opts = { text = true, env = M.build_env() }
  if opts.cwd then
    sys_opts.cwd = opts.cwd
  end
  local result = vim.system(cmd, sys_opts):wait()

  if result.code ~= 0 and not opts.allow_nonzero_json then
    if not opts.silent then
      local msg = result.stderr:match("[^\n]+")
      vim.notify(
        "databricks.nvim: command failed (" .. table.concat(args, " ") .. "): " .. (msg or "unknown error"),
        vim.log.levels.ERROR
      )
    end
    return nil
  end

  local ok, data = pcall(vim.json.decode, result.stdout)
  if not ok or type(data) ~= "table" then
    if not opts.silent then
      vim.notify("databricks.nvim: failed to parse JSON output from " .. table.concat(args, " "), vim.log.levels.ERROR)
    end
    return nil
  end

  return data
end

--- Async variant of databricks_cmd_json. Accepts JSON on non-zero exit.
---@param args string[]
---@param opts {cwd?: string, target?: string}
---@param callback fun(data: table|nil)
function M.databricks_cmd_json_async(args, opts, callback)
  opts = opts or {}
  local args_copy = { unpack(args) }
  table.insert(args_copy, "--output")
  table.insert(args_copy, "json")
  local cmd = M.databricks_cmd(args_copy, opts.target and { target = opts.target } or nil)
  local sys_opts = { text = true, env = M.build_env() }
  if opts.cwd then
    sys_opts.cwd = opts.cwd
  end
  vim.system(cmd, sys_opts, function(result)
    local ok, data = pcall(vim.json.decode, result.stdout)
    if ok and type(data) == "table" then
      callback(data)
    else
      callback(nil)
    end
  end)
end

---@param name string
---@return string
function M.bufname(name)
  return "databricks://" .. name
end

--- Create a named scratch buffer visible in a split.
--- If the buffer already exists and reuse is true, returns it as-is.
--- If reuse is false (or buffer not found), creates a fresh buffer.
---@param name string Unique buffer name
---@return integer buf, integer win
function M.ensure_buffer_window(name)
  local buf = open_buffers[name]
  local win

  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = vim.api.nvim_create_buf(false, true)
    open_buffers[name] = buf
    vim.bo[buf].filetype = "log"
    vim.bo[buf].bufhidden = "hide"
  end

  win = vim.fn.bufwinid(buf)
  if win == -1 then
    vim.cmd("botright 15split")
    vim.api.nvim_win_set_buf(0, buf)
    win = vim.api.nvim_get_current_win()
  end

  pcall(style_output_win, win)

  return buf, win
end

--- Open a terminal running `tail -n +1 -f` on a log file for live output.
--- If a terminal for this buffer already exists, reuses it (does not recreate).
---@param filepath string Path to the log file to tail
---@param opts {name?: string}
function M.run_terminal_tail(filepath, opts)
  opts = opts or {}
  local bufname = M.bufname(opts.name or "run")
  local buf, win = M.ensure_buffer_window(bufname)

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end

  -- avoid spawning a duplicate tail if one's already running in this buffer
  if vim.b[buf].terminal_job_id then
    return
  end

  local cmd = "tail -n +1 -f " .. vim.fn.shellescape(filepath)
  local env = M.build_env()
  local job_id = vim.fn.termopen(cmd, { env = env })

  if job_id <= 0 then
    vim.notify("databricks.nvim: failed to start tail terminal", vim.log.levels.ERROR)
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.b[buf].terminal_job_id = job_id

  vim.api.nvim_buf_call(buf, function()
    -- move to the end of the file
    vim.cmd("normal! G")
  end)
end

--- Build a termopen-compatible shell command that prints a header (with optional
--- venv info) before running the actual command.
---@param cmd string|string[]
---@param venv string|nil
---@return string
function M.build_term_command(cmd, venv)
  local display = type(cmd) == "table" and table.concat(cmd, " ") or tostring(cmd)
  local header
  if venv then
    header =
      string.format("%s#%s %svenv:%s %s%s%s %s|%s %s", DIM, RESET, DIM, RESET, CYAN, venv, RESET, DIM, RESET, display)
  else
    header = string.format("%s#%s %s", DIM, RESET, display)
  end
  return string.format("printf '%%s\\n' '%s' '' && exec %s", header, display)
end

--- Open a terminal split, run a command, and handle exit.
--- On success (exit 0): closes the terminal window after 2.5s.
--- On failure (exit != 0): keeps the window open for inspection.
---@param opts {name?: string, cmd: string|string[], cwd?: string, on_exit?: fun(code: integer)}
function M.run_terminal(opts)
  opts = opts or {}
  local bufname = M.bufname(opts.name or "Terminal")

  local buf, win = M.ensure_buffer_window(bufname)
  local env = M.build_env()

  local shell_cmd = M.build_term_command(opts.cmd, env["VIRTUAL_ENV"])

  local job_id = vim.fn.termopen(shell_cmd, {
    cwd = opts.cwd,
    env = env,
    on_exit = function(_job, code, _event)
      if code == 0 then
        vim.defer_fn(function()
          local w = vim.fn.bufwinid(buf)
          if w ~= -1 then
            vim.api.nvim_win_close(w, true)
          end
        end, 2500)
      end
      if opts.on_exit then
        opts.on_exit(code)
      end
    end,
  })

  if job_id <= 0 then
    vim.notify("databricks.nvim: failed to start terminal (" .. tostring(opts.cmd) .. ")", vim.log.levels.ERROR)
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
end

--- Merge CLI-parsed flags with config defaults.
--- CLI values take precedence when explicitly set (non-nil).
---@param parsed table
---@param defaults table
---@return table
function M.merge_flags(parsed, defaults)
  local merged = vim.deepcopy(defaults)
  for k, v in pairs(parsed) do
    if v ~= nil then
      merged[k] = v
    end
  end
  return merged
end

--- Parse common flags like --refresh for bundle commands.
---@param args string[]
---@return table|nil
function M.parse_bundle_flags(args)
  local opts = {}
  for _, arg in ipairs(args) do
    if arg == "--refresh" then
      opts.refresh = true
    else
      vim.notify("databricks.nvim: unknown flag '" .. arg .. "'", vim.log.levels.ERROR)
      return nil
    end
  end
  return opts
end

return M
