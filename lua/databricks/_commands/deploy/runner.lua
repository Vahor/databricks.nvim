--- Deploy a DAB project using `databricks bundle deploy`.

local dab = require("databricks.dab")
local config = require("databricks.config")
local utils = require("databricks._commands.utils")

local M = {}

---@param parsed_opts Databricks.DeployOpts|nil Parsed options from the deploy parser (nil on parse error)
function M.run(parsed_opts)
  if parsed_opts == nil then
    return -- parse error already notified
  end

  if not dab.is_dab_project() then
    vim.notify("databricks.nvim: not in a DAB project (no databricks.yml found)", vim.log.levels.ERROR)
    return
  end

  local root = dab.find_root()
  if not root then
    return
  end

  -- Merge: CLI flags > config defaults
  local opts = utils.merge_flags(parsed_opts, config.config.commands.deploy)

  local cmd = utils.databricks_cmd({ "bundle", "deploy" })
  if opts.force then
    table.insert(cmd, "--force")
  end
  if opts.auto_approve then
    table.insert(cmd, "--auto-approve")
  end
  if opts.target then
    table.insert(cmd, "--target")
    table.insert(cmd, opts.target)
  end

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

return M
