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
  local suffix = entry.readonly and " (read-only)" or ""
  return string.format("%-35s %s%s", entry.name, val, suffix)
end

local function make_preview(entry)
  -- TODO: style
  local lines = {}
  local indent = string.rep(" ", 4)

  local function render_value(prefix, vtype, value)
    if value ~= nil then
      if vtype == "lookup" then
        table.insert(lines, "lookup: " .. value)
      elseif vtype ~= "complex" then
        table.insert(lines, prefix .. ": " .. utils.stringify(value))
      else
        table.insert(lines, prefix .. ": | ")
        local fullValue = "```\n" .. utils.stringify(value) .. "\n```"
        for line in string.gmatch(fullValue, "[^\n]+") do
          table.insert(lines, indent .. line)
        end
      end
    else
      table.insert(lines, prefix .. ": ")
    end
  end

  table.insert(lines, "---")
  table.insert(lines, "variable: " .. entry.name)
  if entry.vtype and entry.vtype ~= "" then
    table.insert(lines, "type: " .. entry.vtype)
  end
  if entry.description and entry.description ~= "" then
    table.insert(lines, "description: | ")
    for line in string.gmatch(entry.description, "[^\n]+") do
      table.insert(lines, indent .. line)
    end
  end
  finalValue = entry.value or entry.default
  render_value("value", entry.vtype, finalValue)

  if entry.default ~= nil and finalValue ~= entry.default then
    render_value("default", entry.vtype, entry.default)
  end

  if entry.source and entry.source.path and entry.source.line then
    table.insert(lines, "source: `" .. vim.fn.fnamemodify(entry.source.path, ":.") .. ":" .. entry.source.line .. "`")
  end
  table.insert(lines, "---")
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
        end,
      }),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection and selection.value.source and selection.value.source.path then
            vim.cmd("edit " .. vim.fn.fnameescape(selection.value.source.path))
            if selection.value.source.line and selection.value.source.line > 1 then
              vim.api.nvim_win_set_cursor(0, { selection.value.source.line, 0 })
              vim.cmd("normal! zz")
            end
          end
        end)

        map("i", "<C-y>", function()
          local selection = action_state.get_selected_entry()
          if selection then
            local val = selection.value.name
            vim.fn.setreg('"', val)
            vim.fn.setreg("+", val)
            vim.notify("yanked " .. val, vim.log.levels.INFO)
          end
        end)

        return true
      end,
    })
    :find()
end

return M
