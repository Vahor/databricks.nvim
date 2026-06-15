--- @class (exact) Databricks.SparkConfig
--- @field inject boolean

--- @class (exact) Databricks.DABConfig
--- @field schema string|false|nil

--- @class (exact) Databricks.DeployCommandConfig
--- @field force boolean
--- @field auto_approve boolean
--- @field target string|nil

--- @class (exact) Databricks.RunCommandConfig
--- @field cluster_id string|fun():string|nil
--- @field warehouse_id string|fun():string|nil

--- @class (exact) Databricks.CommandsConfig
--- @field deploy Databricks.DeployCommandConfig
--- @field run Databricks.RunCommandConfig

--- @class (exact) Databricks.Config
--- @field auto_detect boolean
--- @field profile string|fun():string|nil
--- @field venv string|fun():string|nil
--- @field verbose boolean
--- @field dab Databricks.DABConfig
--- @field commands Databricks.CommandsConfig
--- @field spark Databricks.SparkConfig
--- @field on_attach nil|fun():nil

local M = {}

--- @type Databricks.Config
M.defaults = {
  auto_detect = true,
  profile = nil,
  venv = nil,
  verbose = false,
  dab = {
    schema = "https://raw.githubusercontent.com/databricks/cli/refs/heads/main/bundle/schema/jsonschema.json",
  },
  commands = {
    deploy = {
      force = false,
      auto_approve = false,
      target = nil,
    },
    run = {
      cluster_id = nil,
      warehouse_id = nil,
    },
  },
  on_attach = nil,
  spark = {
    inject = true,
  },
}

--- @type Databricks.Config
M.config = {}

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("keep", opts, M.defaults)
end

return M
