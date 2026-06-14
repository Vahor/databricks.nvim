--- @class (exact) Databricks.Config
--- @field auto_detect boolean Automatically detect DAB projects on DirChanged/BufEnter
--- @field dab_file string Filename that identifies a DAB project root (default: "databricks.yml")
--- @field profile string|nil Databricks CLI profile to use (overrides auto-detection)
--- @field on_attach nil|fun():nil Called after DAB project detection / config is ready

local M = {}

--- @type Databricks.Config
M.defaults = {
  auto_detect = true,
  dab_file = "databricks.yml",
  profile = nil, -- nil means auto-detect from databricks.yml or DATABRICKS_CONFIG_PROFILE env var
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
