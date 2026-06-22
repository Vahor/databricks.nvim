local M = {}

function M.run()
  local uc = require("databricks.uc")
  local blink = require("databricks.completion.blink.sql")

  vim.notify("databricks.nvim: refreshing Unity Catalog metadata...", vim.log.levels.INFO)
  uc.refresh()
  blink.invalidate_cache()
  vim.notify("databricks.nvim: UC metadata refreshed", vim.log.levels.INFO)
end

function M.help()
  return "refresh  Re-fetch Unity Catalog metadata from Databricks"
end

return M
