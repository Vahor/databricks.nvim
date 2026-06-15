local C = require("databricks.colors")
local config = require("databricks.config")

local M = {}

---@param args string[]
---@return string[]
function M.databricks_cmd(args)
  local p = require("databricks.profile").resolve()
  local cmd = { "databricks" }
  if p then
    table.insert(cmd, "--profile")
    table.insert(cmd, p)
  end
  vim.list_extend(cmd, args)
  return cmd
end

--- Resolve a config value: override > function > env var > string > nil.
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
  local from_env = vim.env[env_var]
  if from_env and from_env ~= "" then
    return from_env
  end
  if type(value) == "string" then
    return value
  end
  return nil
end

function M.build_env()
  local env = vim.fn.environ()
  local venv = M.resolve(config.config.venv, "DATABRICKS_NVIM_VENV")
  if venv then
    env["VIRTUAL_ENV"] = venv
    env["PATH"] = venv .. "/bin:" .. (env["PATH"] or "")
  end
  return env
end

---@param name string
---@return string
function M.bufname(name)
  return "Databricks_" .. name
end

local function ensure_output_buffer(name)
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

  return buf
end

--- All Vimscript calls are wrapped in vim.schedule so this is safe from fast-context.
---@param name string
---@param text string
---@param hl_group? string
function M.append_to_buffer(name, text, hl_group)
  vim.schedule(function()
    local buf = ensure_output_buffer(name)
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

    local win = vim.fn.bufwinid(buf)
    if win ~= -1 then
      pcall(vim.api.nvim_win_set_cursor, win, { vim.api.nvim_buf_line_count(buf), 0 })
    end
  end)
end

---@param name string
---@param text string
function M.append_ansi(name, text)
  vim.schedule(function()
    local buf = ensure_output_buffer(name)
    local ns = vim.api.nvim_create_namespace("databricks_out")
    local lines = vim.split(text, "\n", { plain = true })

    for _, line in ipairs(lines) do
      local line_idx = vim.api.nvim_buf_line_count(buf)
      local segments = C.parse_ansi_segments(line)
      local clean = {}
      for _, seg in ipairs(segments) do
        table.insert(clean, seg.text)
      end
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, { table.concat(clean) })

      local col = 0
      for _, seg in ipairs(segments) do
        if seg.hl and #seg.text > 0 then
          vim.api.nvim_buf_add_highlight(buf, ns, seg.hl, line_idx, col, col + #seg.text)
        end
        col = col + #seg.text
      end
    end

    local win = vim.fn.bufwinid(buf)
    if win ~= -1 then
      pcall(vim.api.nvim_win_set_cursor, win, { vim.api.nvim_buf_line_count(buf), 0 })
    end
  end)
end

function M._create_terminal_buffer(opts)
  local bufname = M.bufname(opts.name or "Terminal")
  local existing = vim.fn.bufnr(bufname)
  if existing ~= -1 then
    vim.api.nvim_buf_delete(existing, { force = true })
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, bufname)

  local win = vim.fn.bufwinid(buf)
  if win == -1 then
    vim.cmd("botright 15split")
    vim.api.nvim_win_set_buf(0, buf)
    win = vim.api.nvim_get_current_win()
  end

  vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"
  vim.wo[win].number = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].statuscolumn = "  "

  return buf, win
end

function M.build_term_command(cmd, venv)
  local display = type(cmd) == "table" and table.concat(cmd, " ") or tostring(cmd)
  local header
  if venv then
    header = string.format(
      "%s#%s %svenv:%s %s%s%s %s|%s %s",
      C.dim,
      C.reset,
      C.dim,
      C.reset,
      C.cyan,
      venv,
      C.reset,
      C.dim,
      C.reset,
      display
    )
  else
    header = string.format("%s#%s %s", C.dim, C.reset, display)
  end
  return string.format("printf '%%s\\n' '%s' '' && exec %s", header, display)
end

function M.run_terminal(opts)
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

function M.merge_flags(parsed, defaults)
  local merged = vim.deepcopy(defaults)
  for k, v in pairs(parsed) do
    if v ~= nil then
      merged[k] = v
    end
  end
  return merged
end

return M
