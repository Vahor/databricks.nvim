--- YAML schema injection for Databricks bundle files.

local config = require("databricks.config")

local M = {}

--- Inject schema into a single yamlls client.
--- @param client table yamlls LSP client
--- @param schema_url string Schema URL to set
local function inject_into_client(client, schema_url)
  local settings = vim.tbl_get(client.config, "settings", "yaml", "schemas") or {}
  settings[schema_url] = config.config.dab.file

  client.config.settings = vim.tbl_deep_extend("force", client.config.settings or {}, {
    yaml = { schemas = settings },
  })

  client:notify("workspace/didChangeConfiguration", {
    settings = client.config.settings,
  })
end

--- Remove a schema URL from a yamlls client's settings.
--- @param client table yamlls LSP client
--- @param schema_url string Schema URL to remove
local function remove_from_client(client, schema_url)
  local schemas = vim.tbl_get(client.config, "settings", "yaml", "schemas")
  if not schemas or not schemas[schema_url] then
    return
  end
  schemas[schema_url] = nil
  client:notify("workspace/didChangeConfiguration", {
    settings = client.config.settings,
  })
end

function M.inject()
  local schema = config.config.dab.schema
  if not schema then
    vim.api.nvim_del_augroup_by_name("DatabricksSchema")
    return
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("DatabricksSchema", { clear = true }),
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or client.name ~= "yamlls" then
        return
      end
      inject_into_client(client, schema)
    end,
  })

  -- Also push to any yamlls clients that have already attached.
  for _, client in ipairs(vim.lsp.get_clients({ name = "yamlls" })) do
    inject_into_client(client, schema)
  end
end

return M
