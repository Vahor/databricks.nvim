local databricks = {}

databricks.config = require("databricks.config")
databricks.dab = require("databricks.dab")
databricks.profile = require("databricks.profile")
databricks.yaml = require("databricks.lsp.yaml")
databricks.python = require("databricks.lsp.python")
databricks.uc = require("databricks.uc")

--- Toggle LSP injection based on whether the current buffer is in a DAB project.
function databricks.toggle_inject()
  if databricks.dab.is_dab_project() then
    databricks.yaml.inject()
    databricks.python.inject()
  else
    databricks.yaml.remove()
    databricks.python.remove()
  end
end

--- Refresh global state (vim.g.*) for external consumers like lualine.
function databricks.refresh()
  vim.g.databricks_dab = databricks.dab.is_dab_project() and 1 or nil
  vim.g.databricks_profile = databricks.profile.resolve()
  vim.g.databricks_run_state = vim.g.databricks_run_state or "idle"
  databricks.profile.resolve_host(true)
end

--- Setup databricks.nvim.
---@param opts table|nil Configuration options (see databricks.config)
function databricks.setup(opts)
  databricks.config.setup(opts)

  local cfg = databricks.config.config

  if not databricks.profile.check() then
    vim.g.databricks_auth_status = true
    vim.notify(
      "databricks.nvim: authentication failed — plugin disabled. Set up a profile with `databricks auth`",
      vim.log.levels.WARN
    )
    return
  end

  vim.g.databricks_auth_status = false
  databricks.refresh()
  databricks.toggle_inject()

  if cfg.auto_detect then
    local prev_dab = databricks.dab.is_dab_project()

    vim.api.nvim_create_autocmd({ "DirChanged", "BufEnter" }, {
      group = vim.api.nvim_create_augroup("DatabricksAuto", { clear = true }),
      callback = function()
        local is_dab = databricks.dab.is_dab_project()
        if is_dab ~= prev_dab then
          databricks.toggle_inject()
          prev_dab = is_dab
        end
        databricks.refresh()
      end,
    })
  end

  if cfg.completion and cfg.completion.uc and cfg.completion.uc.enabled then
    databricks.uc.ensure()
  end

  if cfg.on_attach then
    cfg.on_attach()
  end
end

return databricks
