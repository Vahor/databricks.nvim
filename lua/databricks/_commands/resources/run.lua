local dab = require("databricks.dab")
local utils = require("databricks._commands.utils")

local M = {}

---@param args string[]
---@return table|nil
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

---@param entry {file: string, line: integer}
local function open_resource(entry)
  vim.cmd("edit " .. vim.fn.fnameescape(entry.file))
  if entry.line > 1 then
    vim.api.nvim_win_set_cursor(0, { entry.line, 0 })
    vim.cmd("normal! zz")
  end
end

---@param entries table[]
local function with_picker(entries)
  local ok, _ = pcall(require, "telescope")
  if ok then
    require("databricks._commands.resources.picker").pick(entries, open_resource)
  else
    vim.notify("databricks.nvim: telescope.nvim is required for the resources command", vim.log.levels.ERROR)
  end
end

---@param opts {target: string|nil}
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

  local cmd = utils.databricks_cmd({ "bundle", "summary", "--output", "json", "--include-locations" })
  if opts.target then
    table.insert(cmd, "--target")
    table.insert(cmd, opts.target)
  end

  vim.g.databricks_loading = true
  local result = vim.system(cmd, { cwd = root, text = true, env = utils.build_env() }):wait()
  vim.g.databricks_loading = nil
  if result.code ~= 0 then
    local msg = result.stderr:match("[^\n]+")
    vim.notify("databricks.nvim: bundle summary failed: " .. (msg or "unknown error"), vim.log.levels.ERROR)
    return
  end

  local ok, state = pcall(vim.json.decode, result.stdout)
  if not ok or type(state) ~= "table" then
    vim.notify("databricks.nvim: failed to parse bundle summary output", vim.log.levels.ERROR)
    return
  end

  local resources = state.resources
  if not resources or vim.tbl_isempty(resources) then
    vim.notify("databricks.nvim: no resources found in bundle", vim.log.levels.INFO)
    return
  end

  local locations = state.__locations
  local entries = {}

  for rtype, items in pairs(resources) do
    if type(items) == "table" then
      for name, resource in pairs(items) do
        if type(resource) == "table" then
          local source_file, line = nil, 1
          if locations and locations.locations and locations.files then
            local loc = locations.locations["resources." .. rtype .. "." .. name]
            if loc and #loc > 0 then
              local loc_entry = loc[1]
              if type(loc_entry) == "table" and #loc_entry >= 2 then
                local file_idx = loc_entry[1]
                source_file = locations.files[file_idx + 1]
                line = loc_entry[2] or 1
              end
            end
          end

          table.insert(entries, {
            name = name,
            type = rtype,
            id = resource.id,
            file = source_file and vim.fs.joinpath(root, source_file) or nil,
            line = line,
          })
        end
      end
    end
  end

  if #entries == 0 then
    vim.notify("databricks.nvim: no resources found in bundle", vim.log.levels.INFO)
    return
  end

  with_picker(entries)
end

function M.help()
  return "resources [--target <name>]  Browse DAB resources in a telescope picker (<C-o> opens deployed resource in browser)"
end

return M
