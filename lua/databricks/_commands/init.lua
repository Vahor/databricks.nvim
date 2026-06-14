--- Command registry and dispatcher for `:Databricks` subcommands.

local M = {}

---@type table<string, {parse:function, help:function}>
local subcommands = {
  deploy = require("databricks._commands.deploy.parser"),
}

--- Handle the `:Databricks` command.
---@param args string[] Raw arguments passed to the command
function M.handle(args)
  local subcommand_name = args[1]
  local remaining = {}

  for i = 2, #args do
    remaining[i - 1] = args[i]
  end

  if not subcommand_name or subcommand_name == "" then
    -- No subcommand given: show available commands
    local lines = { "databricks.nvim — available commands:" }
    for name, mod in pairs(subcommands) do
      table.insert(lines, "  " .. mod.help())
    end
    vim:notify(table.concat(lines, "\n"), vim.log.levels.INFO)
    return
  end

  local sub = subcommands[subcommand_name]
  if not sub then
    vim:notify("databricks.nvim: unknown command '" .. subcommand_name .. "'", vim.log.levels.ERROR)
    return
  end

  local opts = sub.parse(remaining)
  local runner_name = "databricks._commands." .. subcommand_name .. ".runner"
  local ok, runner = pcall(require, runner_name)
  if not ok then
    vim:notify("databricks.nvim: failed to load runner for '" .. subcommand_name .. "'", vim.log.levels.ERROR)
    return
  end

  runner.run(opts)
end

--- Tab-completion for `:Databricks` subcommands.
---@param arg_lead string The leading text to complete
---@return string[] Matching subcommand names
function M.complete(arg_lead)
  local matches = {}
  for name, _ in pairs(subcommands) do
    if vim.startswith(name, arg_lead) then
      table.insert(matches, name)
    end
  end
  return matches
end

return M
