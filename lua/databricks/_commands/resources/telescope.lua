local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local urls = require("databricks._commands.urls")

local M = {}

---@param entry {name: string, type: string, file: string|nil, line: integer, id: string|nil}
---@param host string|nil
local function make_display(entry, host)
  local type_label = urls.DISPLAY_TYPES[entry.type] or entry.type
  local relpath = entry.file and vim.fn.fnamemodify(entry.file, ":.") or "(no source)"
  local loc = relpath .. (entry.line > 1 and (":" .. entry.line) or "")
  local icon = urls.resource_url(host, entry) and "\xe2\x96\xb8 " or "  "

  return string.format("%s%-30s [%-10s] %s", icon, entry.name, type_label, loc)
end

---@param entries table[]
---@param open_fn fun(entry: {file: string, line: integer})
function M.pick(entries, open_fn)
  local host = require("databricks.profile").resolve_host()

  for _, entry in ipairs(entries) do
    entry._display = make_display(entry, host)
  end

  table.sort(entries, function(a, b)
    return a._display < b._display
  end)

  pickers
    .new({}, {
      prompt_title = "DAB Resources (<C-o> open in browser)",
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry._display,
            ordinal = entry._display,
            path = entry.file or "",
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = conf.file_previewer({}),
      attach_mappings = function(prompt_bufnr, map)
        map("i", "<C-o>", function()
          local selection = action_state.get_selected_entry()
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
          local ok, err = vim.ui.open(url)
          if ok then
            vim.notify("databricks.nvim: opened " .. url, vim.log.levels.INFO)
          else
            vim.notify("databricks.nvim: failed to open " .. url .. ": " .. (err or "unknown error"), vim.log.levels.ERROR)
          end
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
    })
    :find()
end

return M
