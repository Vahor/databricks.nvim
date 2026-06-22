local dab = require("databricks.dab")
local config = require("databricks.config")
local utils = require("databricks._commands.utils")
local logfile = require("databricks._commands.run.log")

---@class Databricks.DeployOpts
---@field force boolean
---@field auto_approve boolean
---@field target string|nil

local M = {}

M.accepts_target = true

--- Parse CLI arguments for `:Databricks deploy`.
--- Supported flags: --force, --auto-approve. The shared `--target <name>` flag is
--- parsed globally in `_commands/init.lua` and injected as `opts.target`.
--- Returns nil (with error notification) on unknown flags.
---@param args string[]
---@return Databricks.DeployOpts|nil
function M.parse(args)
  local opts = { force = false, auto_approve = false }

  for _, arg in ipairs(args) do
    if arg == "--force" then
      opts.force = true
    elseif arg == "--auto-approve" then
      opts.auto_approve = true
    else
      vim.notify("databricks.nvim: unknown flag '" .. arg .. "'", vim.log.levels.ERROR)
      return nil
    end
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

  -- Persist deploy output to a log file and tail it for live output
  local run_id = logfile.start_run("deploy", "deploy", "deploy")
  if run_id then
    local log_path = logfile.get_path(run_id)
    if log_path then
      utils.run_terminal_tail(log_path, { name = "Deploy" })
    end
  end

  local display_cmd = table.concat(cmd, " ")
  logfile.log("Running: " .. display_cmd .. "\n\n", run_id)

  vim.system(cmd, {
    cwd = root,
    env = utils.build_env(),
    text = true,
  }, function(result)
    vim.schedule(function()
      if result.stdout and result.stdout ~= "" then
        logfile.write(result.stdout, run_id)
      end
      if result.code == 0 then
        logfile.log("\nDeploy succeeded\n", run_id)
      else
        logfile.error("\nDeploy failed (exit " .. result.code .. ")\n", run_id)
        if result.stderr and result.stderr ~= "" then
          logfile.write(result.stderr, run_id)
        end
      end
      logfile.close_run(run_id)
    end)
  end)
end

--- Return a help string for the deploy subcommand.
function M.help()
  return "deploy [--force] [--auto-approve] [--target <name>]  Run `databricks bundle deploy` in a terminal split"
end

return M
