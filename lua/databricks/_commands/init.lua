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
      local ok, mod = pcall(require, "databricks._commands." .. cmd .. ".parser")
      if ok and mod.help then
        table.insert(lines, "  " .. mod.help())
      end
    end
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
    return
  end

  local ok, mod = pcall(require, "databricks._commands." .. name .. ".parser")
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
---@return string[]
function M.complete(arg_lead)
  local matches = {}
  for _, name in ipairs(subcommands) do
    if vim.startswith(name, arg_lead) then
      table.insert(matches, name)
    end
  end
  return matches
end

return M
