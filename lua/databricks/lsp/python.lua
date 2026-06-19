local config = require("databricks.config")

local M = {}

local STUBS_DIR = vim.fs.joinpath(vim.fn.stdpath("cache"), "databricks", "stubs")
local STUB_PATH = vim.fs.joinpath(STUBS_DIR, "__builtins__.pyi")

-- Resolve the shipped stub file relative to this script's location.
local script_path = debug.getinfo(1, "S").source:sub(2)
local STUB_SRC = script_path:gsub("lsp/python%.lua$", "_stubs/__builtins__.pyi")

local function ensure_stubs()
  local f = io.open(STUB_SRC, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()

  vim.fn.mkdir(STUBS_DIR, "p")

  local existing = io.open(STUB_PATH, "r")
  if existing then
    local existing_content = existing:read("*a")
    existing:close()
    if existing_content == content then
      return STUBS_DIR
    end
  end

  vim.fn.writefile(vim.split(content, "\n", { plain = true }), STUB_PATH)
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

--- Inject `spark` type into Python buffers via pyright/basedpyright stub path.
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
end

return M
