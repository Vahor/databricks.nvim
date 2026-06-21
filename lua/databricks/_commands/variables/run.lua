local dab = require("databricks.dab")
local utils = require("databricks._commands.utils")

local M = {}

-- TODO: we can probably infer some of these values from the DAB +profile + config
-- TODO: also check if we can get these from the databricks-cli
local default_variables = {
  { name = "bundle.name", description = "The name of the bundle" },
  { name = "bundle.target", description = "The current target (e.g. dev, prod)" },
  { name = "workspace.current_user.userName", description = "Email of the current user" },
  { name = "workspace.current_user.short_name", description = "Short name of the current user" },
  { name = "workspace.file_path", description = "Remote workspace path for deployment" },
  { name = "workspace.host", description = "Databricks workspace host URL" },
}

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

  local cmd = utils.databricks_cmd({ "bundle", "validate", "--output", "json" }, { target = opts.target })

  local result = vim.system(cmd, { cwd = root, text = true, env = utils.build_env() }):wait()
  local data = {}
  if result.code ~= 0 then
    local msg = result.stderr:match("[^\n]+")
    vim.notify("databricks.nvim: bundle validate failed: " .. (msg or "unknown error"), vim.log.levels.WARN)
  else
    local ok, decoded = pcall(vim.json.decode, result.stdout)
    if ok and type(decoded) == "table" then
      data = decoded
    end
  end

  local files = dab.get_bundle_files(root)
  local yaml_defs = dab.find_variable_definitions(files)

  local entries = {}
  if data.variables then
    for name, vv in pairs(data.variables) do
      local def = yaml_defs[name] or {}
      table.insert(entries, {
        name = name,
        value = vv.value,
        default = vv.default,
        description = vv.description or "",
        vtype = vv.type or (vv.lookup and "lookup" or "unknown"),
        source = {
          path = def.path,
          line = def.line,
        },
      })
    end
  end

  for _, dv in ipairs(default_variables) do
    if not yaml_defs[dv.name] then
      table.insert(entries, {
        name = dv.name,
        description = dv.description,
        vtype = "built-in",
        value = dv.value,
        readonly = true,
      })
    end
  end

  table.sort(entries, function(a, b)
    return a.name < b.name
  end)

  local ok_tel, telescope_picker = pcall(require, "databricks._commands.variables.telescope")
  if not ok_tel then
    vim.notify("databricks.nvim: telescope.nvim is required", vim.log.levels.ERROR)
    return
  end

  telescope_picker.pick(entries)
end

function M.help()
  return "variables [--target <name>]  Browse DAB variables"
end

return M
