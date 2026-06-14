local M = {}

---@class RunOpts
---@field cmd string|string[]
---@field cwd? string

function M.run_terminal(opts)
  local bufname = "Run"
  local buf = vim.fn.bufnr(bufname)

  -- close existing
  if buf ~= -1 then
    vim.api.nvim_buf_delete(buf, { force = true })
  end

  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, bufname)

  local win = vim.fn.bufwinid(buf)
  if win == -1 then
    vim.cmd("botright 15split")
    vim.api.nvim_win_set_buf(0, buf)
    win = vim.api.nvim_get_current_win()
  end

  -- style
  vim.api.nvim_win_set_option(win, "winhl", "Normal:NormalFloat,FloatBorder:FloatBorder")
  vim.api.nvim_win_set_option(win, "number", false)
  vim.api.nvim_win_set_option(win, "signcolumn", "no")
  vim.api.nvim_win_set_option(win, "statuscolumn", "  ")

  -- command
  -- TODO: auto-close on success
  vim.fn.termopen(opts.cmd, {
    cwd = opts.cwd,
    env = {
      TERM = "xterm-256color",
      COLORTERM = "truecolor",
    },
  })

  -- name
  vim.api.nvim_buf_set_name(buf, bufname)
end

return M
