local dab = require("databricks.dab")
local config = require("databricks.config")
local utils = require("databricks._commands.utils")

---@class Databricks.DeployOpts
---@field force boolean
---@field auto_approve boolean
---@field target string|nil

local M = {}

--- Parse CLI arguments for `:Databricks deploy`.
--- Supported flags: --force, --auto-approve, --target <name>
--- Returns nil (with error notification) on unknown flags or missing --target value.
---@param args string[]
---@return Databricks.DeployOpts|nil
function M.parse(args)
  local opts = { force = false, auto_approve = false, target = nil }
  local i = 1

  while i <= #args do
    local arg = args[i]
    if arg == "--force" then
      opts.force = true
    elseif arg == "--auto-approve" then
      opts.auto_approve = true
    elseif arg == "--target" then
      i = i + 1
      local val = args[i]
      if not val or vim.startswith(val, "-") then
        vim.notify("databricks.nvim: --target requires a value", vim.log.levels.ERROR)
        return nil
      end
      opts.target = val
    else
      vim.notify("databricks.nvim: unknown flag '" .. arg .. "'", vim.log.levels.ERROR)
      return nil
    end
    i = i + 1
  end

  return opts
end

--- Run `databricks bundle deploy` in a terminal split.
--- Validates that the current directory is inside a DAB project,
--- merges CLI flags with config defaults, and runs the deploy command.
---@param opts Databricks.DeployOpts|nil
function M.run(opts)
  if opts == nil then
    return
  end

  if not dab.is_dab_project() then
    vim.notify("databricks.nvim: not in a DAB project (no databricks.yml found)", vim.log.levels.ERROR)
    return
  end

  local root = dab.find_root()
  if not root then
    return
  end

  local cmd = utils.databricks_cmd({ "bundle", "deploy" }, { target = opts.target })

  if opts.force then
    table.insert(cmd, "--force")
  end
  if opts.auto_approve then
    table.insert(cmd, "--auto-approve")
  end

  -- TODO: replace run_terminal with tail + terminal view
  utils.run_terminal({
    name = "Deploy",
    cmd = cmd,
    cwd = root,
    on_exit = function(code)
      if code == 0 then
        vim.notify("Deploy succeeded", vim.log.levels.INFO)
      else
        vim.notify("Deploy failed (exit " .. code .. ")", vim.log.levels.ERROR)
      end
    end,
  })
end

--- Return a help string for the deploy subcommand.
function M.help()
  return "deploy [--force] [--auto-approve] [--target <name>]  Run `databricks bundle deploy` in a terminal split"
end

return M
