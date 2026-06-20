local config = require("databricks.config")

local M = { injected = false }

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

--- Remove yamlls schema for DAB files.
function M.remove()
  if not M.injected then
    return
  end
  M.injected = false

  local schema = config.config.dab.schema
  if schema == false then
    return
  end
  if type(schema) ~= "string" then
    schema = config.defaults.dab.schema
  end

  local current = vim.lsp.config["yamlls"]
  if current and current.settings and current.settings.yaml and current.settings.yaml.schemas then
    current.settings.yaml.schemas[schema] = nil
    vim.lsp.config("yamlls", { settings = current.settings })
  end

  for _, client in ipairs(vim.lsp.get_clients({ name = "yamlls" })) do
    if client.config.settings and client.config.settings.yaml and client.config.settings.yaml.schemas then
      client.config.settings.yaml.schemas[schema] = nil
      client:notify("workspace/didChangeConfiguration", { settings = client.config.settings })
    end
  end
end

--- Inject yamlls schema for DAB files. Pre-configures via vim.lsp.config
--- and pushes to any already-attached yamlls clients.
function M.inject()
  if M.injected then
    return
  end

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

  M.injected = true
end

return M
