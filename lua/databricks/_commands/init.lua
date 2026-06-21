local config = require("databricks.config")

--- Command registry and dispatcher for `:Databricks` subcommands.
local M = {}

local subcommands = { "deploy", "run", "log", "resources", "variables", "refresh" }

--- Globally parse the shared `--target <value>` flag out of command arguments.
--- Bundle subcommands (deploy, resources, variables) all accept `--target`, so
--- it is parsed once here instead of being re-implemented in each command.
--- Returns the remaining args (with the flag removed) and the target value.
--- On a malformed flag (missing value, or value that is itself a flag), notifies
--- an error and returns `nil` for the args so the caller aborts.
---@param args string[]
---@return string[]|nil remaining, string|nil target
function M.extract_target(args)
  local remaining = {}
  local target = nil
  local i = 1
  while i <= #args do
    local arg = args[i]
    if arg == "--target" then
      local val = args[i + 1]
      if not val or vim.startswith(val, "-") then
        vim.notify("databricks.nvim: --target requires a value", vim.log.levels.ERROR)
        return nil, nil
      end
      target = val
      i = i + 2
    else
      table.insert(remaining, arg)
      i = i + 1
    end
  end
  return remaining, target
end

---@param args string[]
---@param line1 integer|nil
---@param line2 integer|nil
function M.handle(args, line1, line2)
  local name = args[1]
  local remaining = {}

  for i = 2, #args do
    remaining[i - 1] = args[i]
  end

  if not name or name == "" then
    local lines = { "databricks.nvim — available commands:" }
    for _, cmd in ipairs(subcommands) do
      local ok, mod = pcall(require, "databricks._commands." .. cmd .. ".run")
      if ok and mod.help then
        table.insert(lines, "  " .. mod.help())
      end
    end
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
    return
  end

  local ok, mod = pcall(require, "databricks._commands." .. name .. ".run")
  if not ok then
    vim.notify("databricks.nvim: unknown command '" .. name .. "'", vim.log.levels.ERROR)
    return
  end

  -- Parse the shared `--target` flag globally, but only for commands that opt in
  -- via `accepts_target` (the bundle commands). Commands that don't support it
  -- leave `--target` in the args so their own parser still rejects it as an
  -- unknown flag — preserving typo/misconfig detection.
  local target
  if mod.accepts_target then
    remaining, target = M.extract_target(remaining)
    if remaining == nil then
      return
    end
  end

  local opts
  if mod.parse then
    opts = mod.parse(remaining, line1, line2)
    if opts == nil then
      return
    end
  else
    -- Commands with no custom flags omit `parse`; any leftover arg is unknown.
    if #remaining > 0 then
      vim.notify("databricks.nvim: unknown flag '" .. remaining[1] .. "'", vim.log.levels.ERROR)
      return
    end
    opts = {}
  end

  if target ~= nil then
    opts.target = target
  end
  local defaults = config.config.commands[name] or {}
  opts = vim.tbl_deep_extend("force", defaults, opts)
  mod.run(opts)
end

---@param arg_lead string
---@param cmdline string
---@return string[]
function M.complete(arg_lead, cmdline)
  local args = vim.fn.split(cmdline)

  -- After `log`, complete log file names
  if args[2] == "log" then
    local ok, logfile = pcall(require, "databricks._commands.run.log")
    if ok then
      local logs = logfile.list_logs()
      local matches = {}
      for _, log in ipairs(logs) do
        if vim.startswith(log.name, arg_lead) then
          table.insert(matches, log.name)
        end
      end
      return matches
    end
    return {}
  end

  -- Complete subcommand name
  if args[2] then
    return {}
  end

  local matches = {}
  for _, name in ipairs(subcommands) do
    if vim.startswith(name, arg_lead) then
      table.insert(matches, name)
    end
  end
  return matches
end

return M
