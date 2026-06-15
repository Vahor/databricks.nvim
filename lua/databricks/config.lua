--- @class (exact) Databricks.DABConfig
--- @field schema string|false|nil Schema source: a URL, a file path, or false to disable schema injection

--- @class (exact) Databricks.DeployCommandConfig
--- @field force boolean Add --force to deploy commands (default: false)
--- @field auto_approve boolean Add --auto-approve to deploy commands (default: false)
--- @field target string|nil Default --target value for deploy commands

--- @class (exact) Databricks.RunCommandConfig
--- @field cluster_id string|nil All-purpose cluster ID or serverless cluster for .py execution
--- @field warehouse_id string|nil SQL warehouse ID for .sql execution

--- @class (exact) Databricks.CommandsConfig
--- @field deploy Databricks.DeployCommandConfig Default flags for `:Databricks deploy`
--- @field run Databricks.RunCommandConfig Config for `:Databricks run`

--- @class (exact) Databricks.Config
--- @field auto_detect boolean Automatically detect DAB projects on DirChanged/BufEnter
--- @field profile string|fun():string|nil Databricks CLI profile (overrides auto-detection). Falls back to DATABRICKS_PROFILE env var.
--- @field venv string|fun():string|nil Path to a Python virtualenv. Falls back to DATABRICKS_NVIM_VENV env var.
--- @field dab Databricks.DABConfig DAB-specific configuration
--- @field commands Databricks.CommandsConfig Default flags for CLI subcommands
--- @field on_attach nil|fun():nil Called after DAB project detection / config is ready

local M = {}

--- @type Databricks.Config
M.defaults = {
  auto_detect = true,
  profile = nil, -- string, function, or nil; falls back to DATABRICKS_PROFILE env var
  venv = nil, -- string, function, or nil; falls back to DATABRICKS_NVIM_VENV env var
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
}

--- @type Databricks.Config
M.config = vim.deepcopy(M.defaults)

--- Build and validate user config, merging with defaults.
--- @param opts table|nil User-provided options
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("keep", opts, M.defaults)
end

return M
