if not vim.g.databricks_loaded then
  require("databricks").setup()

  vim.api.nvim_create_user_command("Databricks", function(opts)
    require("databricks._commands").handle(opts.fargs, opts.line1, opts.line2)
  end, {
    nargs = "*",
    range = "%",
    complete = "customlist,v:lua.require'databricks._commands'.complete",
    desc = "Databricks CLI commands (deploy, run, log, resources, refresh)",
  })

  vim.g.databricks_loaded = 1
end
