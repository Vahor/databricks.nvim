local config = require("databricks.config")
local uc = require("databricks.uc")

local source = {}

--- @type blink.cmp.CompletionItem[]|nil
local items_cache = nil

function source.new(_opts)
  return setmetatable({}, { __index = source })
end

function source:enabled()
  local cfg = config.config.completion and config.config.completion.uc
  if not cfg or not cfg.enabled then
    return false
  end
  local ft = vim.bo.filetype
  for _, allowed in ipairs(cfg.filetypes) do
    if ft == allowed then
      return true
    end
  end
  return false
end

function source:get_trigger_characters()
  return { ".", " " }
end

local kinds = nil

local function get_kinds()
  if not kinds then
    kinds = require("blink.cmp.types").CompletionItemKind
  end
  return kinds
end

local function build_items()
  local items = {}
  local kinds = get_kinds()

  if not uc.is_loaded() then
    return items
  end

  for _, cat in ipairs(uc.get_catalogs()) do
    table.insert(items, {
      label = cat,
      kind = kinds.Module,
    })
  end

  for _, schema in ipairs(uc.get_schemas()) do
    table.insert(items, {
      label = schema,
      kind = kinds.Module,
    })
  end

  for _, full_name in ipairs(uc.get_tables()) do
    local comment = uc.get_comment(full_name)
    local item = {
      label = full_name,
      kind = kinds.Struct,
    }
    if comment then
      item.documentation = { kind = "markdown", value = comment }
    end
    table.insert(items, item)

    local cols = uc.get_columns(full_name)
    for col_name, col_info in pairs(cols) do
      table.insert(items, {
        label = col_name,
        kind = kinds.Field,
        detail = col_info.type,
        labelDetails = { description = full_name },
        documentation = col_info.comment and { kind = "markdown", value = col_info.comment } or nil,
      })
    end
  end

  return items
end

function source:get_completions(_ctx, callback)
  if not items_cache then
    items_cache = build_items()
  end

  callback({
    items = items_cache,
    is_incomplete_backward = false,
    is_incomplete_forward = false,
  })
end

function source:resolve(item, callback)
  callback(item)
end

function source.invalidate_cache()
  items_cache = nil
end

return source
