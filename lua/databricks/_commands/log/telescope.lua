local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local previewers = require("telescope.previewers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local logfile = require("databricks._commands.run.log")

local M = {}

local log_previewer = previewers.new_buffer_previewer({
  define_preview = function(self, entry)
    local path = entry.path
    if not path or not vim.uv.fs_stat(path) then
      return
    end
    local lines = vim.fn.readfile(path, "", 1000)
    for i, line in ipairs(lines) do
      lines[i] = line:gsub("\x1b%[[%d;]*m", "")
    end
    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
    vim.bo[self.state.bufnr].filetype = "log"
  end,
})

function M.pick(logs)
  pickers
    .new({}, {
      prompt_title = "Databricks Run Logs",
      finder = finders.new_table({
        results = logs,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.display,
            ordinal = entry.display,
            path = entry.path,
          }
        end,
      }),
      sorter = sorters.get_generic_fuzzy_sorter(),
      previewer = log_previewer,
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            logfile.open_log(selection.value)
          end
        end)
        return true
      end,
    })
    :find()
end

return M
