local config = require("databricks.config")

local M = {}

local function schema_settings(schema_url)
  return {
    yaml = {
      schemas = {
        [schema_url] = config.config.dab.patterns,
      },
    },
  }
end

--- Pre-configure yamlls via vim.lsp.config so the schema is present
--- from the start, not pushed after init.
---@param schema_url string
local function configure_lsp(schema_url)
  local current = vim.lsp.config["yamlls"]
  vim.lsp.config("yamlls", {
    settings = vim.tbl_deep_extend("force", current and current.settings or {}, schema_settings(schema_url)),
  })
end

--- Push schema settings to an already-running yamlls client.
---@param client table
---@param schema_url string
local function push_to_client(client, schema_url)
  client.config.settings = vim.tbl_deep_extend("force", client.config.settings or {}, schema_settings(schema_url))
  client:notify("workspace/didChangeConfiguration", { settings = client.config.settings })
end

--- Inject yamlls schema for DAB files. Pre-configures via vim.lsp.config
--- and pushes to any already-attached yamlls clients.
function M.inject()
  local schema = config.config.dab.schema
  if schema == false then
    return
  end
  if type(schema) ~= "string" then
    schema = config.defaults.dab.schema
  end

  configure_lsp(schema)

  for _, client in ipairs(vim.lsp.get_clients({ name = "yamlls" })) do
    push_to_client(client, schema)
  end
end

return M
