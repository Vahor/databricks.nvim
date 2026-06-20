local dab = require("databricks.dab")
local utils = require("databricks._commands.utils")

local M = {}

function M.parse(args)
  local opts = { target = nil }
  local i = 1
  while i <= #args do
    local arg = args[i]
    if arg == "--target" then
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

function M.run(opts)
  if not dab.is_dab_project() then
    vim.notify("databricks.nvim: not in a DAB project", vim.log.levels.ERROR)
    return
  end
  local root = dab.find_root()
  if not root then
    return
  end

  local cmd = utils.databricks_cmd({ "bundle", "validate", "--output", "json" })
  if opts.target then
    table.insert(cmd, "--target")
    table.insert(cmd, opts.target)
  end

  local result = vim.system(cmd, { cwd = root, text = true, env = utils.build_env() }):wait()
  if result.code ~= 0 then
    local msg = result.stderr:match("[^\n]+")
    vim.notify("databricks.nvim: bundle validate failed: " .. (msg or "unknown error"), vim.log.levels.ERROR)
    return
  end

  local ok, data = pcall(vim.json.decode, result.stdout)
  if not ok or type(data) ~= "table" then
    vim.notify("databricks.nvim: failed to parse validate output", vim.log.levels.ERROR)
    return
  end

  local variables = data.variables

  -- TODO: add default variables (target, ...)

  local entries = {}
  for name, vv in pairs(variables) do
    table.insert(entries, {
      name = name,
      value = vv.value,
      default = vv.default,
      description = vv.description or "",
      vtype = vv.type or (vv.lookup and "lookup" or ""),
      -- TODO: add yaml files lookup to find where the variable is defined
    })
  end
  table.sort(entries, function(a, b)
    return a.name < b.name
  end)

  local ok, telescope_picker = pcall(require, "databricks._commands.variables.telescope")
  if not ok then
    vim.notify("databricks.nvim: telescope.nvim is required for log picker", vim.log.levels.ERROR)
    return
  end

  telescope_picker.pick(entries)
end

function M.help()
  return "variables [--target <name>]  Browse DAB variables"
end

return M
