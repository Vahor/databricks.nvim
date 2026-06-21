local config = require("databricks.config")
local uc = require("databricks.uc")
local source = {}

--- raw_name -> resolved full_name, built once per uc reload
--- @type table<string, string>|nil
local table_name_index = nil

function source.new(_opts)
  return setmetatable({}, { __index = source })
end

function source:enabled()
  local cfg = config.config.completion and config.config.completion.uc
  if not cfg or not cfg.enabled then
    return false
  end
  local ft = vim.bo.filetype
  return ft == "sql"
end

function source:get_trigger_characters()
  return { ".", " " }
end

local cached_kinds = nil
local function get_kinds()
  if not cached_kinds then
    cached_kinds = require("blink.cmp.types").CompletionItemKind
  end
  return cached_kinds
end

-- stage 0: catalogs only
local function build_catalog_items()
  local items = {}
  local kinds = get_kinds()
  if not uc.is_loaded() then
    return items
  end
  for _, cat in ipairs(uc.get_catalogs()) do
    table.insert(items, { label = cat, kind = kinds.Module })
  end
  return items
end

-- stage 1: schemas under a given catalog, e.g. catalog = "samples"
-- -> "samples.tpch" items, labeled with just the bare schema part
local function build_schema_items(catalog)
  local items = {}
  local kinds = get_kinds()
  if not uc.is_loaded() then
    return items
  end
  local prefix = catalog .. "."
  for _, full_schema in ipairs(uc.get_schemas()) do
    if vim.startswith(full_schema, prefix) then
      local bare = full_schema:sub(#prefix + 1)
      table.insert(items, { label = bare, kind = kinds.Module })
    end
  end
  return items
end

-- stage 2: tables under a given schema, e.g. schema = "samples.tpch"
-- -> labeled with just the bare table part
local function build_table_only_items(schema)
  local items = {}
  local kinds = get_kinds()
  if not uc.is_loaded() then
    return items
  end
  for _, full_name in ipairs(uc.get_tables_for_schema(schema)) do
    local bare = full_name:match("([^.]+)$") or full_name
    local comment = uc.get_comment(full_name)
    local item = { label = bare, kind = kinds.Struct }
    if comment then
      item.documentation = { kind = "markdown", value = comment }
    end
    table.insert(items, item)
  end
  return items
end

-- maps any suffix-matchable name (bare table name) and full name -> full_name
local function build_table_name_index()
  local index = {}
  for _, full_name in ipairs(uc.get_tables()) do
    index[full_name] = full_name
    local bare = full_name:match("([^.]+)$")
    if bare then
      index[bare] = full_name
    end
  end
  return index
end

local function get_table_name_index()
  if not table_name_index then
    table_name_index = build_table_name_index()
  end
  return table_name_index
end

local function resolve_table_name(raw_name)
  return get_table_name_index()[raw_name]
end

local sql_relation_query_str = [[
  (relation
    (object_reference) @table
    alias: (identifier)? @alias)
]]
local sql_relation_query = nil

local function get_referenced_tables(bufnr)
  local refs = {}
  bufnr = bufnr or 0

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "sql")
  if not ok or not parser then
    return refs
  end

  local trees = parser:parse()
  if not trees or not trees[1] then
    return refs
  end

  if not sql_relation_query then
    local ok_query, query = pcall(vim.treesitter.query.parse, "sql", sql_relation_query_str)
    if not ok_query then
      return refs
    end
    sql_relation_query = query
  end

  local root = trees[1]:root()

  -- a capture can come back as a single node OR a list of nodes (e.g. for
  -- quantified captures like `alias: (identifier)?`); normalize to the
  -- first node in both cases
  local function first_node(node_or_list)
    if not node_or_list then
      return nil
    end
    if node_or_list.range then
      return node_or_list
    end
    return node_or_list[1]
  end

  local ok_iter = pcall(function()
    for _, match, _ in sql_relation_query:iter_matches(root, bufnr, 0, -1, { all = false }) do
      local table_node, alias_node
      for id, node in pairs(match) do
        local name = sql_relation_query.captures[id]
        if name == "table" then
          table_node = first_node(node)
        elseif name == "alias" then
          alias_node = first_node(node)
        end
      end

      if table_node then
        local full_name = vim.treesitter.get_node_text(table_node, bufnr)
        refs[full_name] = full_name
        if alias_node then
          local alias = vim.treesitter.get_node_text(alias_node, bufnr)
          refs[alias] = full_name
        end
      end
    end
  end)
  if not ok_iter then
    return {}
  end

  return refs
end

-- if cursor is right after "alias." or "table.", capture both the alias and
-- whether there's a "." at all (i.e. are we in column-position)
local function get_cursor_prefix(ctx)
  local line = ctx.line or ""
  local col = ctx.cursor and ctx.cursor[2] or #line
  local before = line:sub(1, col)
  local alias = before:match("([%w_]+)%.[%w_]*$")
  return before, alias
end

-- naive but cheap: are we positioned where a table reference is expected
-- (after FROM / JOIN, optionally followed by a partial dotted path like
-- "samples." or "samples.tpch.")?
local function in_table_position(before)
  return before:match("[Ff][Rr][Oo][Mm]%s+[%w_.`]*$") ~= nil or before:match("[Jj][Oo][Ii][Nn]%s+[%w_.`]*$") ~= nil
end

local function build_column_items(bufnr, ctx, alias)
  local items = {}
  local kinds = get_kinds()
  local refs = get_referenced_tables(bufnr)

  local target_refs = refs
  if alias then
    -- cursor follows "alias." / "table." - narrow to just that one
    target_refs = refs[alias] and { [alias] = refs[alias] } or {}
  end

  local seen_tables = {}
  for _, raw_name in pairs(target_refs) do
    local resolved = resolve_table_name(raw_name)
    if resolved and not seen_tables[resolved] then
      seen_tables[resolved] = true
      local cols = uc.get_columns(resolved)
      for col_name, col_info in pairs(cols) do
        table.insert(items, {
          label = col_name,
          kind = kinds.Field,
          detail = col_info.type,
          labelDetails = { description = resolved },
          documentation = col_info.comment and { kind = "markdown", value = col_info.comment } or nil,
        })
      end
    end
  end

  return items
end

function source:get_completions(ctx, callback)
  local bufnr = ctx.bufnr or 0
  local before, alias = get_cursor_prefix(ctx)

  local items
  if in_table_position(before) then
    local raw = before:match("[%w_.`]*$") or ""
    local trailing_dot = raw:sub(-1) == "."
    -- strip the trailing dot before splitting so "samples." and "samples"
    -- both yield {"samples"}; trailing_dot tells us if that segment is
    -- "complete" (move to next stage) or still being typed (filter this stage)
    local stripped = trailing_dot and raw:sub(1, -2) or raw
    local segments = {}
    if stripped ~= "" then
      for part in (stripped .. "."):gmatch("([^.]*)%.") do
        table.insert(segments, part)
      end
    end

    if #segments == 0 then
      -- nothing typed yet -> catalogs
      items = build_catalog_items()
    elseif #segments == 1 and not trailing_dot then
      -- "samp" (still typing the catalog name) -> catalogs, blink filters
      items = build_catalog_items()
    elseif #segments == 1 then
      -- "samples." -> schemas in that catalog
      items = build_schema_items(segments[1])
    elseif #segments == 2 and not trailing_dot then
      -- "samples.tp" (still typing the schema name) -> schemas, blink filters
      items = build_schema_items(segments[1])
    else
      -- "samples.tpch." (or deeper) -> tables in that schema
      local schema = segments[1] .. "." .. segments[2]
      items = build_table_only_items(schema)
    end
  elseif alias then
    -- "alias." or "table." outside table position -> that table's columns
    items = build_column_items(bufnr, ctx, alias)
  else
    -- elsewhere (e.g. SELECT / WHERE with no alias prefix) -> columns
    -- from all tables referenced in the query
    items = build_column_items(bufnr, ctx, nil)
  end

  callback({
    items = items,
    is_incomplete_backward = false,
    is_incomplete_forward = false,
  })
end

function source:resolve(item, callback)
  callback(item)
end

function source.invalidate_cache()
  table_name_index = nil
end

return source
