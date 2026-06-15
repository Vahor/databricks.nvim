local M = {}

--- Resolve a config value that can be a string, a function, or nil (with env var fallback).
--- @param value string|fun():string|nil
--- @param env_var string Environment variable name to check as fallback
--- @return string|nil
local function resolve(value, env_var)
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
  local venv = resolve(require("databricks.config").config.venv, "DATABRICKS_NVIM_VENV")
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

--- Open a terminal split, run a command, and handle exit.
--- On success (exit 0): closes the terminal window.
--- On failure (exit ≠ 0): keeps the window open for inspection.
function M.run_terminal(opts)
  ---@type RunTerminalOpts
  opts = opts or {}
  local buf, win = M._create_terminal_buffer(opts)

  -- Merge terminal env with current process env (preserves PATH etc.)
  local env = M.build_env()
  env["TERM"] = "xterm-256color"

  -- Build header line showing the command and venv (if configured)
  local cmd_str = type(opts.cmd) == "table" and table.concat(opts.cmd, " ") or tostring(opts.cmd)
  local header = "# " .. cmd_str
  if env["VIRTUAL_ENV"] then
    header = "# venv: " .. env["VIRTUAL_ENV"] .. " | " .. cmd_str
  end
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, { header, "" })

  -- Run the command via termopen
  local job_id = vim.fn.termopen(opts.cmd, {
    cwd = opts.cwd,
    env = env,
    on_exit = function(_job, code, _event)
      if code == 0 then
        local w = vim.fn.bufwinid(buf)
        if w ~= -1 then
          vim.api.nvim_win_close(w, true)
        end
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

--- Append text to a named output buffer. Creates the buffer and a split on first use.
---@param name string Short display name (e.g. "Run")
---@param text string Text to append
function M.append_to_buffer(name, text)
  local bufname = M.bufname(name)
  local buf = vim.fn.bufnr(bufname)

  if buf == -1 then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, bufname)
    vim.bo[buf].bufhidden = "wipe"
    vim.cmd("botright 15split")
    vim.api.nvim_win_set_buf(0, buf)
    vim.wo.number = false
    vim.wo.signcolumn = "no"
  end

  local lines = vim.split(text, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)

  -- Scroll to bottom
  local win = vim.fn.bufwinid(buf)
  if win ~= -1 then
    vim.api.nvim_win_call(win, function()
      vim.cmd("normal! G")
    end)
  end
end

return M
