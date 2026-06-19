--- Command registry and dispatcher for `:Databricks` subcommands.
local M = {}

local subcommands = { "deploy", "run" }

---@param args string[]
function M.handle(args)
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

  local opts = mod.parse(remaining)
  if opts ~= nil then
    mod.run(opts)
  end
end

---@param arg_lead string
---@param cmdline string
---@return string[]
function M.complete(arg_lead, cmdline)
  local args = vim.fn.split(cmdline)
  -- Once a known subcommand is fully present, stop completing.
  if args[2] and vim.tbl_contains(subcommands, args[2]) then
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
