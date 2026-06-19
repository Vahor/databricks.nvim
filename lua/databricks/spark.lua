local config = require("databricks.config")

local M = {}

local STUBS_DIR = vim.fs.joinpath(vim.fn.stdpath("cache"), "databricks", "stubs")
local SPARK_STUB = "\nfrom pyspark.sql import SparkSession\nspark: SparkSession\n"

local function find_builtins_stub()
  local mason = vim.fn.stdpath("data")
  local candidates = {}

  for _, name in ipairs({ "pyright", "basedpyright" }) do
    local base = vim.fs.joinpath(mason, "mason", "packages", name, "dist")
    candidates[#candidates + 1] = vim.fs.joinpath(base, "typeshed-fallback", "stdlib", "builtins.pyi")
    candidates[#candidates + 1] = vim.fs.joinpath(base, "typeshed-fallback", "typeshed", "stdlib", "builtins.pyi")
  end

  for _, dir in ipairs(vim.fn.split(vim.env.PATH or "", ":")) do
    for _, name in ipairs({ "pyright-langserver", "basedpyright-langserver" }) do
      local bin = vim.fs.joinpath(dir, name)
      if vim.uv.fs_stat(bin) then
        local base = vim.fs.joinpath(dir, "..", "dist")
        candidates[#candidates + 1] = vim.fs.joinpath(base, "typeshed-fallback", "stdlib", "builtins.pyi")
        candidates[#candidates + 1] = vim.fs.joinpath(base, "typeshed-fallback", "typeshed", "stdlib", "builtins.pyi")
      end
    end
  end

  for _, path in ipairs(candidates) do
    local normalized = vim.fs.normalize(path)
    if vim.uv.fs_stat(normalized) then
      return normalized
    end
  end

  return nil
end

local function ensure_stubs()
  vim.fn.mkdir(STUBS_DIR, "p")
  local stub_path = vim.fs.joinpath(STUBS_DIR, "__builtins__.pyi")

  local content
  local src = find_builtins_stub()
  if src then
    local f = io.open(src, "r")
    if f then
      content = f:read("*a") .. SPARK_STUB
      f:close()
    end
  end

  if not content then
    content = SPARK_STUB
  end

  local existing = io.open(stub_path, "r")
  if existing then
    local existing_content = existing:read("*a")
    existing:close()
    if existing_content == content then
      return STUBS_DIR
    end
  end

  vim.fn.writefile(vim.split(content, "\n", { plain = true }), stub_path)
  return STUBS_DIR
end

--- Deep-merge spark stubPath into an existing settings table.
local function merge_settings(settings, stubs_dir)
  return vim.tbl_deep_extend("force", settings or {}, {
    python = { analysis = { stubPath = stubs_dir } },
  })
end

--- Pre-configure pyright/basedpyright via vim.lsp.config (Neovim >= 0.11).
local function configure_lsp(stubs_dir)
  for _, name in ipairs({ "pyright", "basedpyright" }) do
    local current = vim.lsp.config[name]
    vim.lsp.config(name, { settings = merge_settings(current and current.settings, stubs_dir) })
  end
end

--- Push stubPath to an already-running LSP client.
local function push_to_client(client, stubs_dir)
  client.config.settings = merge_settings(client.config.settings, stubs_dir)
  client:notify("workspace/didChangeConfiguration", { settings = client.config.settings })
end

--- Inject `spark` type into Python buffers via pyright/basedpyright stub path.
--- Creates or reuses a stubs directory in Neovim's cache, pointing stubPath there.
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
