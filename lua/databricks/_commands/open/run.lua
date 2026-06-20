local dab = require("databricks.dab")
local utils = require("databricks._commands.utils")
local urls = require("databricks._commands.urls")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}

local GROUP_MODES = { "type", "dir", "name" }

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

---@param entry {name: string, type: string, file: string|nil, line: integer, id: string|nil}
---@param host string|nil
---@param group_mode string
local function make_display(entry, host, group_mode)
  local type_label = urls.DISPLAY_TYPES[entry.type] or entry.type
  local relpath = entry.file and vim.fn.fnamemodify(entry.file, ":.") or "(no source)"
  local loc = relpath .. (entry.line > 1 and (":" .. entry.line) or "")
  local icon = urls.resource_url(host, entry) and "\xe2\x96\xb8 " or "  "

  if group_mode == "dir" then
    return string.format("%s%-45s [%-8s] %s", icon, loc, type_label, entry.name)
  elseif group_mode == "name" then
    return string.format("%s%-30s [%-8s] %s", icon, entry.name, type_label, loc)
  else
    return string.format("%s[%-8s] %-30s %s", icon, type_label, entry.name, loc)
  end
end

---@param entries table[]
local function open_selection(entries)
  local host = require("databricks.profile").resolve_host()

  local function open_picker(group_idx)
    group_idx = group_idx or 1
    local group_mode = GROUP_MODES[group_idx]

    for _, entry in ipairs(entries) do
      entry._display = make_display(entry, host, group_mode)
    end

    table.sort(entries, function(a, b)
      return a._display < b._display
    end)

    pickers
      .new({}, {
        prompt_title = string.format("Open DAB Resource — grouped by %s (<C-g> cycle)", group_mode),
        finder = finders.new_table({
          results = entries,
          entry_maker = function(entry)
            return {
              value = entry,
              display = entry._display,
              ordinal = entry._display,
              path = entry.file,
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
          map({ "i", "n" }, "<C-g>", function()
            actions.close(prompt_bufnr)
            vim.schedule(function()
              open_picker(group_idx % #GROUP_MODES + 1)
            end)
          end)

          actions.select_default:replace(function()
            local selection = action_state.get_selected_entry()
            actions.close(prompt_bufnr)
            if not selection then
              return
            end
            if not selection.value.id then
              vim.notify("databricks.nvim: resource not yet deployed (no id)", vim.log.levels.INFO)
              return
            end
            local url = urls.resource_url(host, selection.value)
            if not url then
              vim.notify(
                "databricks.nvim: no web URL mapping for resource type '" .. selection.value.type .. "'",
                vim.log.levels.INFO
              )
              return
            end
            vim.ui.open(url)
            vim.notify("databricks.nvim: opened " .. url, vim.log.levels.INFO)
          end)

          return true
        end,
      })
      :find()
  end

  open_picker(1)
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

  local result = vim.system(cmd, { cwd = root, text = true, env = utils.build_env() }):wait()
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

  open_selection(entries)
end

function M.help()
  return "open [--target <name>]  Open a DAB resource in the browser"
end

return M
