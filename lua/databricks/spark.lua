--- Inject the `spark` type into Python buffers via pyright/basedpyright.
---
--- Finds pyright's real builtins.pyi at runtime, appends `spark: SparkSession`,
--- writes the result to Neovim's cache dir, and points `stubPath` there.
--- Standard builtins (print, len, ...) are preserved because we start from
--- the real file rather than shipping a replacement.

local config = require("databricks.config")

local M = {}

local CACHE_DIR = vim.fs.joinpath(vim.fn.stdpath("cache"), "databricks")
local STUBS_DIR = vim.fs.joinpath(CACHE_DIR, "stubs")

--- Append this to the standard builtins.
local SPARK_STUB = "\nfrom pyspark.sql import SparkSession\nspark: SparkSession\n"

--- Locate pyright's builtins.pyi.
--- @return string|nil
local function find_pyright_builtins()
  -- Mason (most common)
  for _, pkg in ipairs({ "pyright", "basedpyright" }) do
    local p = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "packages", pkg,
      "node_modules", "pyright", "dist", "typeshed-fallback", "stdlib", "builtins.pyi")
    if vim.uv.fs_stat(p) then
      return p
    end
  end
  -- Resolve via pyright-langserver on PATH
  local bin = vim.fn.exepath("pyright-langserver")
  if bin ~= "" then
    local real = vim.uv.fs_realpath(bin)
    if real then
      local dir = vim.fn.fnamemodify(real, ":h")
      local p = vim.fs.normalize(vim.fs.joinpath(dir, "..", "dist", "typeshed-fallback", "stdlib", "builtins.pyi"))
      if vim.uv.fs_stat(p) then
        return p
      end
    end
  end
end

--- Build the merged builtins.pyi in the cache dir.
--- @return string|nil stubs_dir
local function ensure_merged_builtins()
  local source = find_pyright_builtins()
  if not source then
    vim.notify("databricks.nvim: could not find pyright/basedpyright installation", vim.log.levels.ERROR)
    return nil
  end

  vim.fn.mkdir(STUBS_DIR, "p")

  local merged = table.concat(vim.fn.readfile(source), "\n") .. SPARK_STUB
  local stub_file = vim.fs.joinpath(STUBS_DIR, "builtins.pyi")

  -- Skip write if already up-to-date.
  if vim.uv.fs_stat(stub_file) then
    local existing = table.concat(vim.fn.readfile(stub_file), "\n") .. "\n"
    if existing == merged .. "\n" then
      return STUBS_DIR
    end
  end

  vim.fn.writefile(vim.split(merged, "\n", { plain = true }), stub_file)
  return STUBS_DIR
end

--- Deep-merge spark stubPath into an existing settings table.
local function merge_settings(settings, stubs_dir)
  return vim.tbl_deep_extend("force", settings or {}, {
    python = { analysis = { stubPath = stubs_dir } },
  })
end

--- Pre-configure pyright/basedpyright via vim.lsp.config (Neovim ≥ 0.11).
local function configure_lsp(stubs_dir)
  for _, name in ipairs({ "pyright", "basedpyright" }) do
    local current = vim.lsp.config[name]
    vim.lsp.config(name, { settings = merge_settings(current and current.settings, stubs_dir) })
  end
end

--- Push to an already-running client.
local function push_to_client(client, stubs_dir)
  client.config.settings = merge_settings(client.config.settings, stubs_dir)
  client:notify("workspace/didChangeConfiguration", { settings = client.config.settings })
end

--- Remove stubPath from a running client.
local function remove_from_client(client)
  local sp = vim.tbl_get(client.config, "settings", "python", "analysis", "stubPath")
  if not sp then return end
  client.config.settings.python.analysis.stubPath = nil
  client:notify("workspace/didChangeConfiguration", { settings = client.config.settings })
end

function M.inject()
  local spark = config.config.spark
  if not spark or not spark.inject then
    vim.api.nvim_del_augroup_by_name("DatabricksSpark")
    for _, c in ipairs(vim.lsp.get_clients()) do
      if c.name == "pyright" or c.name == "basedpyright" then remove_from_client(c) end
    end
    return
  end

  local stubs_dir = ensure_merged_builtins()
  if not stubs_dir then return end

  configure_lsp(stubs_dir)

  for _, c in ipairs(vim.lsp.get_clients()) do
    if c.name == "pyright" or c.name == "basedpyright" then push_to_client(c, stubs_dir) end
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
