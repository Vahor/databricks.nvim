--- @class (exact) Databricks.SparkConfig
--- @field inject boolean  Inject `spark: SparkSession` type into Python buffers via pyright stubs

--- @class (exact) Databricks.UCCompletionConfig
--- @field enabled boolean  Enable Unity Catalog completion
--- @field catalogs "auto"|string[]|(fun():string)|string  Which catalogs to use. Supports glob patterns. "auto" = all.
--- @field schemas "auto"|string[]|(fun():string)|string  Which schemas to use. Supports glob patterns on full_name (catalog.schema). "auto" = all.

--- @class (exact) Databricks.CompletionConfig
--- @field uc Databricks.UCCompletionConfig  Unity Catalog completion settings

--- @class (exact) Databricks.DABConfig
--- @field schema string|false|nil  Schema URL for yamlls, local path, or false to disable

--- @class (exact) Databricks.DeployCommandConfig
--- @field force boolean  Add --force to deploy command
--- @field auto_approve boolean  Add --auto-approve to deploy command

--- @class (exact) Databricks.RunCommandConfig
--- @field cluster_id string|(fun():string)|nil  Cluster ID for Python execution. Falls back to DATABRICKS_NVIM_CLUSTER_ID
--- @field warehouse_id string|(fun():string)|nil  SQL warehouse ID. Falls back to DATABRICKS_NVIM_WAREHOUSE_ID

--- @class (exact) Databricks.LogConfig
--- @field dir string  Directory for run logs
--- @field auto_close_ms integer|false  Milliseconds before auto-closing successful terminal (false to disable)

--- @class (exact) Databricks.LogCommandConfig
--- @field open boolean  Default --open for `:Databricks log`

--- @class (exact) Databricks.CommandsConfig
--- @field deploy Databricks.DeployCommandConfig  Default flags for `:Databricks deploy`
--- @field run Databricks.RunCommandConfig  Default flags for `:Databricks run`
--- @field log Databricks.LogCommandConfig  Default flags for `:Databricks log`

--- @class (exact) Databricks.Config
--- @field auto_detect boolean  Automatically detect DAB projects on DirChanged/BufEnter
--- @field profile string|(fun():string)|nil  Databricks CLI profile. Falls back to DATABRICKS_PROFILE
--- @field venv string|(fun():string)|nil  Path to Python virtualenv. Falls back to DATABRICKS_NVIM_VENV
--- @field verbose boolean  Log exact API URLs and query bodies to the output buffer
--- @field target string|(fun():string)|nil  Default `--target` for bundle commands (deploy, resources, variables). Falls back to DATABRICKS_BUNDLE_TARGET
--- @field dab Databricks.DABConfig  DAB project configuration
--- @field commands Databricks.CommandsConfig  Default flags for CLI subcommands
--- @field spark Databricks.SparkConfig  Spark type injection configuration
--- @field log Databricks.LogConfig  Log configuration
--- @field on_attach nil|fun():nil  Called after initial detection / config is ready
--- @field completion Databricks.CompletionConfig  Completion configuration

local M = {}

--- @type Databricks.Config
M.defaults = {
  auto_detect = true,
  profile = nil,
  verbose = false,
  target = nil,
  dab = {
    schema = "https://raw.githubusercontent.com/databricks/cli/refs/heads/main/bundle/schema/jsonschema.json",
  },
  commands = {
    deploy = {
      force = false,
      auto_approve = false,
    },
    run = {
      cluster_id = nil,
      warehouse_id = nil,
    },
    log = {
      open = true,
    },
  },
  on_attach = nil,
  log = {
    dir = vim.fn.stdpath("data") .. "/databricks.nvim",
    auto_close_ms = 2500,
  },
  spark = {
    inject = true,
  },
  completion = {
    uc = {
      enabled = true,
      catalogs = "auto",
      schemas = "auto",
    },
  },
}

--- @type Databricks.Config
M.config = {}

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("keep", opts, M.defaults)
end

--- Walk a dotted path into M.config (e.g. "commands.run.cluster_id").
--- Returns the value, or nil if any segment is missing.
---@param path string
---@return any
function M.get(path)
  local current = M.config
  for _, segment in ipairs(vim.split(path, "%.")) do
    if type(current) ~= "table" then
      return nil
    end
    current = current[segment]
  end
  return current
end

return M
