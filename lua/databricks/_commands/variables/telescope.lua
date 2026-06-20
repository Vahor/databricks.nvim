local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local utils = require("databricks._commands.utils")

local M = {}

local function make_display(entry)
  local val = utils.stringify(entry.value)
  if #val > 40 then
    val = val:sub(1, 40) .. "..."
  end
  return string.format("%-30s %s", entry.name, val)
end

local function make_preview(entry)
  -- TODO: make it pretty. maybe markdown?
  local lines = { "Variable: " .. entry.name, string.rep("-", 50) }
  if entry.description and entry.description ~= "" then
    table.insert(lines, "Description: " .. entry.description)
  end
  if entry.vtype and entry.vtype ~= "" then
    table.insert(lines, "Type: " .. entry.vtype)
  end
  table.insert(lines, "")
  table.insert(lines, "Resolved value: " .. utils.stringify(entry.value))
  if entry.default ~= nil then
    table.insert(lines, "Default: " .. utils.stringify(entry.default))
  end
  return table.concat(lines, "\n")
end

function M.pick(entries)
  pickers
    .new({}, {
      prompt_title = "DAB Variables",
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          return {
            value = entry,
            display = make_display(entry),
            ordinal = entry.name,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = previewers.new_buffer_previewer({
        define_preview = function(self, entry)
          if not entry then
            return
          end
          local lines = vim.split(make_preview(entry.value), "\n")
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
          vim.bo[self.state.bufnr].filetype = "markdown"

          -- vim.api.nvim_set_option_value("modifiable", true, { buf = self.state.bufnr })
        end,
      }),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            -- TODO: add action to copy to clipboard
            vim.notify(
              string.format("%s = %s", selection.value.name, utils.stringify(selection.value.value)),
              vim.log.levels.INFO
            )
          end
        end)

        -- TODO: add shift enter or something to go to definition

        return true
      end,
    })
    :find()
end

return M
