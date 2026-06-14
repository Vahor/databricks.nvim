if not vim.g.databricks_loaded then
  require("databricks").setup()

  vim.api.nvim_create_user_command("Databricks", function(opts)
    local commands = require("databricks._commands")
    commands.handle(opts.fargs)
  end, {
    nargs = "*",
    complete = "customlist,v:lua.require'databricks._commands'.complete",
    desc = "Databricks CLI commands (deploy, etc.)",
  })

  vim.g.databricks_loaded = 1
end
