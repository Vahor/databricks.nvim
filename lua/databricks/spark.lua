--- Inject the `spark` type into Python buffers via pyright/basedpyright stubs.
--- Writes a `builtins.pyi` to Neovim's cache directory and sets
--- `python.analysis.stubPath` so pyright treats `spark` as a SparkSession,
--- matching the Databricks notebook environment.

local config = require("databricks.config")

local M = {}

local STUBS_DIR = vim.fs.joinpath(vim.fn.stdpath("cache"), "databricks", "stubs")

--- Ensure the stubs directory and builtins.pyi exist on disk.
--- @return string|nil stubs_dir Absolute path to the stubs directory, or nil on failure
local function ensure_stubs()
  local ok = pcall(vim.fn.mkdir, STUBS_DIR, "p")
  if not ok then
    vim.notify("databricks.nvim: failed to create stubs directory " .. STUBS_DIR, vim.log.levels.ERROR)
    return nil
  end

  local stub_file = vim.fs.joinpath(STUBS_DIR, "builtins.pyi")
  local content = { "from pyspark.sql import SparkSession", "", "spark: SparkSession" }

  -- Only write if missing to avoid unnecessary I/O.
  if not vim.uv.fs_stat(stub_file) then
    local write_ok = pcall(vim.fn.writefile, content, stub_file)
    if not write_ok then
      vim.notify("databricks.nvim: failed to write " .. stub_file, vim.log.levels.ERROR)
      return nil
    end
  end

  return STUBS_DIR
end

--- Inject stubPath into a single pyright/basedpyright client.
--- @param client table LSP client
--- @param stubs_dir string Absolute path to the stubs directory
local function inject_into_client(client, stubs_dir)
  client.config.settings = vim.tbl_deep_extend("force", client.config.settings or {}, {
    python = {
      analysis = {
        stubPath = stubs_dir,
      },
    },
  })

  client:notify("workspace/didChangeConfiguration", {
    settings = client.config.settings,
  })
end

--- Remove stubPath from a single client.
--- @param client table LSP client
local function remove_from_client(client)
  local stub_path = vim.tbl_get(client.config, "settings", "python", "analysis", "stubPath")
  if not stub_path then
    return
  end
  client.config.settings.python.analysis.stubPath = nil
  client:notify("workspace/didChangeConfiguration", {
    settings = client.config.settings,
  })
end

--- Start injecting spark type stubs into pyright.
---
--- Creates a `DatabricksSpark` autocmd group on `LspAttach` and also
--- applies to any pyright/basedpyright clients that are already attached.
function M.inject()
  local spark_config = config.config.spark
  if not spark_config or not spark_config.inject then
    vim.api.nvim_del_augroup_by_name("DatabricksSpark")
    -- Clean up any already-attached clients
    for _, client in ipairs(vim.lsp.get_clients()) do
      if client.name == "pyright" or client.name == "basedpyright" then
        remove_from_client(client)
      end
    end
    return
  end

  local stubs_dir = ensure_stubs()
  if not stubs_dir then
    return
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("DatabricksSpark", { clear = true }),
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client then
        return
      end
      if client.name ~= "pyright" and client.name ~= "basedpyright" then
        return
      end
      inject_into_client(client, stubs_dir)
    end,
  })

  -- Also push to any pyright clients that have already attached.
  for _, client in ipairs(vim.lsp.get_clients()) do
    if client.name == "pyright" or client.name == "basedpyright" then
      inject_into_client(client, stubs_dir)
    end
  end
end

return M
