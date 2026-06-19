local databricks = {}

databricks.config = require("databricks.config")
databricks.dab = require("databricks.dab")
databricks.profile = require("databricks.profile")
databricks.schema = require("databricks.schema")
databricks.spark = require("databricks.spark")

--- Refresh global state (vim.g.*) for external consumers like lualine.
function databricks.refresh()
  vim.g.databricks_dab = databricks.dab.is_dab_project() and 1 or nil
  vim.g.databricks_profile = databricks.profile.resolve()
  vim.g.databricks_run_state = vim.g.databricks_run_state or "idle"
end

--- Setup databricks.nvim.
---@param opts table|nil Configuration options (see databricks.config)
function databricks.setup(opts)
  databricks.config.setup(opts)

  local cfg = databricks.config.config

  databricks.schema.inject()
  databricks.spark.inject()
  databricks.refresh()

  if cfg.auto_detect then
    vim.api.nvim_create_autocmd({ "DirChanged", "BufEnter" }, {
      group = vim.api.nvim_create_augroup("DatabricksAuto", { clear = true }),
      callback = function()
        databricks.refresh()
      end,
    })
  end

  if cfg.on_attach then
    cfg.on_attach()
  end
end

return databricks
