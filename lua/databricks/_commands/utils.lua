local C = require("databricks.colors")

local M = {}

local ANSI_ESC = string.char(27)

--- Parse a line with ANSI SGR codes into {text, hl_group} segments.
---@param line string
---@return table[] segments
local function parse_ansi_segments(line)
  local segments = {}
  local pos = 1
  local current_hl = nil

  while pos <= #line do
    local esc_start = line:find(ANSI_ESC .. "[", pos, true)
    if not esc_start then
      table.insert(segments, { text = line:sub(pos), hl = current_hl })
      break
    end
    if esc_start > pos then
      table.insert(segments, { text = line:sub(pos, esc_start - 1), hl = current_hl })
    end
    local esc_end = line:find("m", esc_start, true)
    if not esc_end then
      table.insert(segments, { text = line:sub(pos), hl = current_hl })
      break
    end
    local codes_str = line:sub(esc_start + 2, esc_end - 1)
    for code in codes_str:gmatch("[0-9]+") do
      local mapped = C.ansi_to_hl[code]
      if mapped == false then
        current_hl = nil
      elseif mapped then
        current_hl = mapped
      end
    end
    pos = esc_end + 1
  end

  return segments
end

-- Cached to avoid vim.env / vim.fn.environ() calls from timer context.
local cached_base_env = nil
local cached_profile = nil
local cached_venv = nil
local cache_built = false

--- One-time capture of env vars that are illegal to read from fast/timer context.
local function build_cache()
  if cache_built then
    return
  end
  cache_built = true
  cached_base_env = vim.fn.environ()
  cached_profile = require("databricks.profile").resolve()
  cached_venv = M.resolve(require("databricks.config").config.venv, "DATABRICKS_NVIM_VENV")
end

--- Build a `databricks` CLI command array, inserting --profile when configured.
---@param args string[] Arguments after `databricks` (e.g. {"api", "get", "/..."})
---@return string[] Full command array
function M.databricks_cmd(args)
  build_cache()
  local cmd = { "databricks" }
  if cached_profile then
    table.insert(cmd, "--profile")
    table.insert(cmd, cached_profile)
  end
  vim.list_extend(cmd, args)
  return cmd
end

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
--- Uses cached base env to avoid vim.fn.environ() in timer context.
---@return table env table suitable for termopen or vim.system
function M.build_env()
  build_cache()
  local env = vim.deepcopy(cached_base_env)
  if cached_venv then
    env["VIRTUAL_ENV"] = cached_venv
    env["PATH"] = cached_venv .. "/bin:" .. (env["PATH"] or "")
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

--- Append text to a named output buffer. Creates the buffer and a split on first use.
--- All Vimscript calls are wrapped in vim.schedule so this is safe from fast-context.
---@param name string Short display name (e.g. "Run")
---@param text string Text to append
---@param hl_group? string Optional highlight group (e.g. "Comment" for gray logs)
function M.append_to_buffer(name, text, hl_group)
  vim.schedule(function()
    local bufname = M.bufname(name)
    local buf = vim.fn.bufnr(bufname)

    if buf == -1 then
      buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(buf, bufname)
      vim.bo[buf].bufhidden = "wipe"
      vim.cmd("botright 15split")
      vim.api.nvim_win_set_buf(0, buf)
      local win = vim.api.nvim_get_current_win()
      vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"
      vim.wo[win].number = false
      vim.wo[win].signcolumn = "no"
      vim.wo[win].statuscolumn = "  "
    end

    local lines = vim.split(text, "\n", { plain = true })
    local start = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)

    if hl_group then
      local ns = vim.api.nvim_create_namespace("databricks_out")
      for i, line in ipairs(lines) do
        if #line > 0 then
          vim.api.nvim_buf_add_highlight(buf, ns, hl_group, start + i - 1, 0, -1)
        end
      end
    end

    -- Scroll to bottom
    local win = vim.fn.bufwinid(buf)
    if win ~= -1 then
      pcall(vim.api.nvim_win_set_cursor, win, { vim.api.nvim_buf_line_count(buf), 0 })
    end
  end)
end

--- Append text with ANSI SGR codes, rendering them as Neovim highlights.
---@param name string Short display name (e.g. "Run")
---@param text string Text possibly containing ANSI escape sequences
function M.append_ansi(name, text)
  vim.schedule(function()
    local bufname = M.bufname(name)
    local buf = vim.fn.bufnr(bufname)

    if buf == -1 then
      buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(buf, bufname)
      vim.bo[buf].bufhidden = "wipe"
      vim.cmd("botright 15split")
      vim.api.nvim_win_set_buf(0, buf)
      local win = vim.api.nvim_get_current_win()
      vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"
      vim.wo[win].number = false
      vim.wo[win].signcolumn = "no"
      vim.wo[win].statuscolumn = "  "
    end

    local ns = vim.api.nvim_create_namespace("databricks_out")
    local lines = vim.split(text, "\n", { plain = true })

    for _, line in ipairs(lines) do
      local line_idx = vim.api.nvim_buf_line_count(buf)
      local segments = parse_ansi_segments(line)

      -- Build clean text from segments
      local clean = {}
      for _, seg in ipairs(segments) do
        table.insert(clean, seg.text)
      end
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, { table.concat(clean) })

      -- Apply per-segment highlights
      local col = 0
      for _, seg in ipairs(segments) do
        if seg.hl and #seg.text > 0 then
          vim.api.nvim_buf_add_highlight(buf, ns, seg.hl, line_idx, col, col + #seg.text)
        end
        col = col + #seg.text
      end
    end

    -- Scroll to bottom
    local win = vim.fn.bufwinid(buf)
    if win ~= -1 then
      pcall(vim.api.nvim_win_set_cursor, win, { vim.api.nvim_buf_line_count(buf), 0 })
    end
  end)
end

return M
