if not vim.g.databricks_loaded then
  vim.schedule(function()
    require("databricks").setup()
  end)

  vim.g.databricks_loaded = 1
end
