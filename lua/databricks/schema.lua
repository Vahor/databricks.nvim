--- YAML schema injection for Databricks bundle files.

local config = require("databricks.config")

local M = {}

function M.inject()
  local schema = config.config.schema
  if not schema then
    return
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("DatabricksSchema", { clear = true }),
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or client.name ~= "yamlls" then
        return
      end

      local settings = vim.tbl_get(client.config, "settings", "yaml", "schemas") or {}
      settings[schema] = config.config.dab_file -- add only on dab_file

      client.config.settings = vim.tbl_deep_extend("force", client.config.settings or {}, {
        yaml = { schemas = settings },
      })

      client.notify("workspace/didChangeConfiguration", {
        settings = client.config.settings,
      })
    end,
  })
end

return M
