if not vim.g.databricks_loaded then
  require("databricks").setup()
  vim.g.databricks_loaded = 1
end
