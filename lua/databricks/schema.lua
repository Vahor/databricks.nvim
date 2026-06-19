local config = require("databricks.config")

local M = {}

--- Inject DAB JSON schema into a yamlls client's settings.
---@param client table
---@param schema_url string
local function inject_into_client(client, schema_url)
  client.config.settings = vim.tbl_deep_extend("force", client.config.settings or {}, {
    yaml = {
      schemas = {
        [schema_url] = config.config.dab.patterns,
      },
    },
  })

  client:notify("workspace/didChangeConfiguration", {
    settings = client.config.settings,
  })
end

--- Inject yamlls schema for DAB files. Sets up an LspAttach autocmd
--- and pushes to any already-attached yamlls clients.
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

return M
