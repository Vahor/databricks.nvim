local C = require("databricks.colors")

local M = {}

--- Resolve a config value with full priority: override > function > env var > string > nil.
--- @param value string|fun():string|nil Config value (string, function, or nil)
--- @param env_var string Environment variable name to check as fallback
--- @param override string|nil CLI / explicit override (highest priority)
--- @return string|nil
function M.resolve(value, env_var, override)
  if override ~= nil then
    return override
  end
  if type(value) == "function" then
    return value()
  end
  local from_env = vim.env[env_var]
  if from_env and from_env ~= "" then
    return from_env
  end
  if type(value) == "string" then
    return value
  end
  return nil
end

--- Build environment table with venv activated (if configured).
--- Merges the current process env with VIRTUAL_ENV and PATH pointing to the venv binary dir.
---@return table env table suitable for termopen or vim.system
function M.build_env()
  local env = vim.fn.environ()
  local venv = M.resolve(require("databricks.config").config.venv, "DATABRICKS_NVIM_VENV")
  if venv then
    env["VIRTUAL_ENV"] = venv
    env["PATH"] = venv .. "/bin:" .. (env["PATH"] or "")
  end
  return env
end

---@class RunTerminalOpts
---@field name string Buffer / display name (e.g. "Deploy")
---@field cmd string|string[] Command to run
---@field cwd string Working directory
---@field on_exit? fun(exit_code: number) Called after the command finishes

--- Build the full buffer name from a short display name.
---@param name string
---@return string
function M.bufname(name)
  return "Databricks_" .. name
end

--- Create and setup a terminal buffer. Returns buf, win.
--- This is split out so it can be tested independently of termopen.
---@param opts RunTerminalOpts
---@return integer buf, integer win
function M._create_terminal_buffer(opts)
  local bufname = M.bufname(opts.name or "Terminal")

  -- Close existing buffer with same name
  local existing = vim.fn.bufnr(bufname)
  if existing ~= -1 then
    vim.api.nvim_buf_delete(existing, { force = true })
  end

  -- Create a new scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, bufname)

  -- Open in a horizontal split (reuse window if buffer already in one)
  local win = vim.fn.bufwinid(buf)
  if win == -1 then
    vim.cmd("botright 15split")
    vim.api.nvim_win_set_buf(0, buf)
    win = vim.api.nvim_get_current_win()
  end

  -- Terminal-friendly window options
  vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"
  vim.wo[win].number = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].statuscolumn = "  "

  return buf, win
end

--- Build a termopen-compatible shell command that prints a header (with optional
--- venv info) before running the actual command.
---@param cmd string|string[] The command to run
---@param venv string|nil Resolved venv path (or nil)
---@return string shell_cmd
function M.build_term_command(cmd, venv)
  local display = type(cmd) == "table" and table.concat(cmd, " ") or tostring(cmd)
  local header
  if venv then
    header = string.format("%s#%s %svenv:%s %s%s%s %s|%s %s", C.dim, C.reset, C.dim, C.reset, C.cyan, venv, C.reset, C.dim, C.reset, display)
  else
    header = string.format("%s#%s %s", C.dim, C.reset, display)
  end
  return string.format("printf '%%s\\n' '%s' '' && exec %s", header, display)
end

--- Open a terminal split, run a command, and handle exit.
--- On success (exit 0): closes the terminal window.
--- On failure (exit ≠ 0): keeps the window open for inspection.
function M.run_terminal(opts)
  ---@type RunTerminalOpts
  opts = opts or {}
  local buf, win = M._create_terminal_buffer(opts)

  local env = M.build_env()
  env["TERM"] = "xterm-256color"

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
--- CLI values take precedence when explicitly set (non-nil, or true for booleans).
--- Keys present only in defaults are kept as-is.
---@param parsed table CLI-parsed options (from parser.parse())
---@param defaults table Config defaults (from config.config.commands.<name>)
---@return table Merged table
function M.merge_flags(parsed, defaults)
  local merged = vim.deepcopy(defaults)
  for k, v in pairs(parsed) do
    if v ~= nil then
      merged[k] = v
    end
  end
  return merged
end

--- Find a buffer by its full name using only fast-context-safe API calls.
---@param bufname string
---@return integer buf, or -1
local function find_buf_by_name(bufname)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_name(b) == bufname then
      return b
    end
  end
  return -1
end

--- Find a window that contains the given buffer using fast-context-safe API.
---@param buf integer
---@return integer win, or -1
local function find_win_by_buf(buf)
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_buf(w) == buf then
      return w
    end
  end
  return -1
end

--- Append text to a named output buffer. Creates the buffer and a split on first use.
--- Uses a terminal buffer so ANSI escape codes render natively.
--- Safe to call from fast-context (schedules Vimscript operations).
---@param name string Short display name (e.g. "Run")
---@param text string Text to append
function M.append_to_buffer(name, text)
  vim.schedule(function()
    local bufname = M.bufname(name)
    local buf = find_buf_by_name(bufname)

    if buf == -1 then
      buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(buf, bufname)
      vim.bo[buf].bufhidden = "wipe"
      vim.cmd("botright 15split")
      vim.api.nvim_win_set_buf(0, buf)
      vim.wo.number = false
      vim.wo.signcolumn = "no"
      -- Start a cat process so we can feed text via nvim_chan_send.
      -- The terminal renders ANSI escape codes (e.g. dim/gray).
      vim.fn.termopen("cat")
      vim.b[buf].databricks_out_chan = vim.bo[buf].channel
    end

    local chan = vim.b[buf] and vim.b[buf].databricks_out_chan
    if chan and vim.api.nvim_chan_send then
      vim.api.nvim_chan_send(chan, text)
    end

    -- Scroll to bottom
    local win = find_win_by_buf(buf)
    if win ~= -1 then
      pcall(vim.api.nvim_win_set_cursor, win, { vim.api.nvim_buf_line_count(buf), 0 })
    end
  end)
end

return M
