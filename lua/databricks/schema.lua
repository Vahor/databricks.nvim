local config = require("databricks.config")

local DAB_FILE = "databricks.yml"

local M = {}

local function inject_into_client(client, schema_url)
  local settings = vim.tbl_get(client.config, "settings", "yaml", "schemas") or {}
  settings[schema_url] = DAB_FILE

  client.config.settings = vim.tbl_deep_extend("force", client.config.settings or {}, {
    yaml = { schemas = settings },
  })

  client:notify("workspace/didChangeConfiguration", {
    settings = client.config.settings,
  })
end

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
    pcall(vim.api.nvim_del_augroup_by_name, "DatabricksSchema")
    return
  end

  local ok, augroup = pcall(vim.api.nvim_create_augroup, "DatabricksSchema", { clear = true })
  if not ok then
    return
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    group = augroup,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or client.name ~= "yamlls" then
        return
      end
      inject_into_client(client, schema)
    end,
  })

  for _, client in ipairs(vim.lsp.get_clients({ name = "yamlls" })) do
    inject_into_client(client, schema)
  end
end

function M.remove()
  local schema = config.config.dab.schema
  if schema then
    for _, client in ipairs(vim.lsp.get_clients({ name = "yamlls" })) do
      remove_from_client(client, schema)
    end
  end
  pcall(vim.api.nvim_del_augroup_by_name, "DatabricksSchema")
end

return M
