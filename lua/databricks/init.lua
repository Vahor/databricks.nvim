local databricks = {}

databricks.config = require("databricks.config")
databricks.dab = require("databricks.dab")
databricks.profile = require("databricks.profile")
databricks.yaml = require("databricks.lsp.yaml")
databricks.python = require("databricks.lsp.python")
databricks.uc = require("databricks.uc")
databricks.bundle_cache = require("databricks._commands.bundle_cache")

local did_setup = false

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
  databricks.profile.resolve_host(true)
end

local function warm_bundle_cache()
  local root = databricks.dab.find_root()
  if not root then
    return
  end

  databricks.bundle_cache.warm({
    root = root,
  })
end

--- Setup databricks.nvim.
---@param opts table|nil Configuration options (see databricks.config)
function databricks.setup(opts)
  if did_setup then
    return
  end
  did_setup = true

  databricks.config.setup(opts)

  require("databricks._commands").register()

  local cfg = databricks.config.config

  if cfg.auto_detect then
    local prev_dab = databricks.dab.is_dab_project()
    local prev_root = databricks.dab.find_root()

    vim.api.nvim_create_autocmd({ "DirChanged", "BufEnter" }, {
      group = vim.api.nvim_create_augroup("DatabricksAuto", { clear = true }),
      callback = function()
        local is_dab = databricks.dab.is_dab_project()
        local current_root = databricks.dab.find_root()
        if is_dab ~= prev_dab then
          vim.schedule(function()
            databricks.toggle_inject()
          end)
          prev_dab = is_dab
        end
        if is_dab and current_root and current_root ~= prev_root then
          warm_bundle_cache()
          prev_root = current_root
        end
        databricks.refresh()
      end,
    })
  end

  vim.schedule(function()
    databricks.profile.check_async(function(ok)
      if not ok then
        vim.g.databricks_auth_status = false
        vim.notify(
          "databricks.nvim: authentication failed — plugin disabled. Set up a profile with `databricks auth`",
          vim.log.levels.WARN
        )
        return
      end

      vim.g.databricks_auth_status = true
      databricks.refresh()
      vim.schedule(function()
        databricks.toggle_inject()
      end)
      warm_bundle_cache()

      if cfg.completion and cfg.completion.uc and cfg.completion.uc.enabled then
        databricks.uc.ensure()
      end

      if cfg.on_attach then
        cfg.on_attach()
      end
    end)
  end)
end

return databricks
