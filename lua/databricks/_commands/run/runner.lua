--- Dispatch `:Databricks run` to Python or SQL execution.

local config = require("databricks.config")
local utils = require("databricks._commands.utils")
local python = require("databricks._commands.run.python")
local sql = require("databricks._commands.run.sql")

local M = {}

local BUF_NAME = "Run"

---@param opts Databricks.RunOpts|nil Parsed options from the run parser
function M.run(opts)
  if opts == nil then return end

  local cfg = config.config.commands.run
  local cluster_id = opts.cluster_id or cfg.cluster_id
  local warehouse_id = opts.warehouse_id or cfg.warehouse_id

  vim.g.databricks_run_state = "running"

  if opts.language == "python" then
    if not cluster_id then
      utils.append_to_buffer(BUF_NAME, "Error: no cluster_id configured. Set commands.run.cluster_id or use --cluster-id.\n")
      vim.g.databricks_run_state = "error"
      return
    end
    python.run(opts.code, cluster_id)
  elseif opts.language == "sql" then
    if not warehouse_id then
      utils.append_to_buffer(BUF_NAME, "Error: no warehouse_id configured. Set commands.run.warehouse_id or use --warehouse-id.\n")
      vim.g.databricks_run_state = "error"
      return
    end
    sql.run(opts.code, warehouse_id)
  end
end

return M
