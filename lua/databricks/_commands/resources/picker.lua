local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}

local GROUP_MODES = { "type", "dir", "name" }

local DISPLAY_TYPES = {
  jobs = "job",
  pipelines = "pipeline",
  dashboards = "dashboard",
  schemas = "schema",
  volumes = "volume",
  apps = "app",
  experiments = "experiment",
  clusters = "cluster",
  registered_models = "model",
  model_serving_endpoints = "endpoint",
  quality_monitors = "monitor",
}

---@param entry {name: string, type: string, file: string|nil, line: integer}
---@param group_mode string
local function make_display(entry, group_mode)
  local type_label = DISPLAY_TYPES[entry.type] or entry.type
  local relpath = entry.file and vim.fn.fnamemodify(entry.file, ":.") or "(no source)"
  local loc = relpath .. (entry.line > 1 and (":" .. entry.line) or "")

  if group_mode == "dir" then
    return string.format("%-45s [%-8s] %s", loc, type_label, entry.name)
  elseif group_mode == "name" then
    return string.format("%-30s [%-8s] %s", entry.name, type_label, loc)
  else
    return string.format("[%-8s] %-30s %s", type_label, entry.name, loc)
  end
end

---@param entries table[]
---@param open_fn fun(entry: {file: string, line: integer})
function M.pick(entries, open_fn)
  local function open_picker(group_idx)
    group_idx = group_idx or 1
    local group_mode = GROUP_MODES[group_idx]

    for _, entry in ipairs(entries) do
      entry._display = make_display(entry, group_mode)
    end

    table.sort(entries, function(a, b)
      return a._display < b._display
    end)

    pickers.new({}, {
      prompt_title = string.format("DAB Resources — grouped by %s (<C-g> to cycle)", group_mode),
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
      previewer = conf.file_previewer({}),
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
          if selection and selection.value.file then
            open_fn(selection.value)
          end
        end)

        return true
      end,
    }):find()
  end

  open_picker(1)
end

return M
