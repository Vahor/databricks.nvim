local config = require("databricks.config")

local M = {}

local STUBS_DIR = vim.fs.joinpath(vim.fn.stdpath("cache"), "databricks", "stubs")

local function ensure_stubs()
  vim.fn.mkdir(STUBS_DIR, "p")
  vim.fn.writefile(
    { "from pyspark.sql import SparkSession", "spark: SparkSession" },
    vim.fs.joinpath(STUBS_DIR, "builtins.pyi")
  )
  return STUBS_DIR
end

local function merge_settings(settings, stubs_dir)
  return vim.tbl_deep_extend("force", settings or {}, {
    python = { analysis = { stubPath = stubs_dir } },
  })
end

local function configure_lsp(stubs_dir)
  for _, name in ipairs({ "pyright", "basedpyright" }) do
    local current = vim.lsp.config[name]
    vim.lsp.config(name, { settings = merge_settings(current and current.settings, stubs_dir) })
  end
end

local function push_to_client(client, stubs_dir)
  client.config.settings = merge_settings(client.config.settings, stubs_dir)
  client:notify("workspace/didChangeConfiguration", { settings = client.config.settings })
end

function M.inject()
  local spark = config.config.spark
  if not spark or not spark.inject then
    return
  end

  local stubs_dir = ensure_stubs()
  if not stubs_dir then
    return
  end

  configure_lsp(stubs_dir)

  for _, c in ipairs(vim.lsp.get_clients()) do
    if c.name == "pyright" or c.name == "basedpyright" then
      push_to_client(c, stubs_dir)
    end
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("DatabricksSpark", { clear = true }),
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and (client.name == "pyright" or client.name == "basedpyright") then
        push_to_client(client, stubs_dir)
      end
    end,
  })
end

return M
