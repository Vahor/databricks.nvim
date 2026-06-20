if not vim.g.databricks_loaded then
  require("databricks").setup()

  vim.api.nvim_create_user_command("Databricks", function(opts)
    require("databricks._commands").handle(opts.fargs)
  end, {
    nargs = "*",
    complete = "customlist,v:lua.require'databricks._commands'.complete",
    desc = "Databricks CLI commands (deploy, run, log, resources)",
  })

  vim.g.databricks_loaded = 1
end
