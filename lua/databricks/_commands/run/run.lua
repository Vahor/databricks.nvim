local config = require("databricks.config")
local utils = require("databricks._commands.utils")
local logfile = require("databricks._commands.run.log")
local profile = require("databricks.profile")
local python = require("databricks._commands.run.python")
local sql = require("databricks._commands.run.sql")

---@class Databricks.RunOpts
---@field language "python"|"sql"
---@field code string
---@field cluster_id string|nil
---@field warehouse_id string|nil
---@field log_name string|boolean|nil

local M = {}

---@return string|nil
local function get_code()
  -- TODO: add range selection support

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if #lines == 0 or (#lines == 1 and lines[1] == "") then
    vim.notify("databricks.nvim: empty buffer", vim.log.levels.ERROR)
    return nil
  end
  return table.concat(lines, "\n")
end

---@return "python"|"sql"|nil
--- Detect the language from the current buffer's filetype.
---@return "python"|"sql"|nil
local function detect_language()
  local ft = vim.bo.filetype
  if ft == "python" then
    return "python"
  end
  if ft == "sql" then
    return "sql"
  end
  return nil
end

--- Parse CLI args, capture code and language from current buffer.
--- Supported flags: --cluster-id, --warehouse-id, --log [name]
---@param args string[]
---@return Databricks.RunOpts|nil
function M.parse(args)
  local code = get_code()
  if not code then
    return nil
  end

  local language = detect_language()
  if not language then
    vim.notify(
      "databricks.nvim: unsupported filetype '" .. vim.bo.filetype .. "'. Supported: python, sql",
      vim.log.levels.ERROR
    )
    return nil
  end

  local opts = { language = language, code = code }
  local i = 1

  while i <= #args do
    local arg = args[i]
    if arg == "--cluster-id" then
      i = i + 1
      local val = args[i]
      if not val or vim.startswith(val, "-") then
        vim.notify("databricks.nvim: --cluster-id requires a value", vim.log.levels.ERROR)
        return nil
      end
      opts.cluster_id = val
    elseif arg == "--warehouse-id" then
      i = i + 1
      local val = args[i]
      if not val or vim.startswith(val, "-") then
        vim.notify("databricks.nvim: --warehouse-id requires a value", vim.log.levels.ERROR)
        return nil
      end
      opts.warehouse_id = val
    elseif arg == "--log" then
      if i < #args and not vim.startswith(args[i + 1], "-") then
        i = i + 1
        opts.log_name = args[i]
      else
        opts.log_name = true
      end
    else
      vim.notify("databricks.nvim: unknown flag '" .. arg .. "'", vim.log.levels.ERROR)
      return nil
    end
    i = i + 1
  end

  return opts
end

--- Run the code on Databricks using the appropriate runner (Python or SQL).
--- Resolves cluster_id / warehouse_id from config, CLI override, or env var.
--- Sets up a persistent log file and opens a tail terminal for live output.
---@param opts Databricks.RunOpts|nil
function M.run(opts)
  if opts == nil then
    return
  end

  local p = profile.resolve() or "none"
  local buf_name = vim.api.nvim_buf_get_name(0)

  local function source_name(buf_name)
    if buf_name == "" then
      return "selection"
    end
    local dab_root = require("databricks.dab").find_root()
    local root = dab_root or vim.fn.getcwd()
    local prefix = root .. "/"
    if vim.startswith(buf_name, prefix) then
      local rel = buf_name:sub(#prefix + 1)
      return rel:gsub("_", "__"):gsub("/", "_")
    end
    return vim.fn.fnamemodify(buf_name, ":t")
  end

  local source = source_name(buf_name)
  local log_path = logfile.start_run(p, source, opts.log_name)
  if log_path then
    utils.run_terminal_tail(log_path, { name = source })
  end

  local cfg = config.config.commands.run
  local cluster_id = utils.resolve(cfg.cluster_id, "DATABRICKS_NVIM_CLUSTER_ID", opts.cluster_id)
  local warehouse_id = utils.resolve(cfg.warehouse_id, "DATABRICKS_NVIM_WAREHOUSE_ID", opts.warehouse_id)

  vim.g.databricks_run_state = "running"

  if opts.language == "python" then
    if not cluster_id then
      logfile.error(
        "Error: no cluster_id configured.\n  Set commands.run.cluster_id, use --cluster-id, or DATABRICKS_NVIM_CLUSTER_ID env var.\n"
      )
      vim.g.databricks_run_state = "error"
      logfile.close_run()
      return
    end
    python.run(opts.code, cluster_id)
  elseif opts.language == "sql" then
    if not warehouse_id then
      logfile.error("Error: no warehouse_id configured. Set commands.run.warehouse_id or use --warehouse-id.\n")
      vim.g.databricks_run_state = "error"
      logfile.close_run()
      return
    end
    sql.run(opts.code, warehouse_id)
  end
end

function M.help()
  return "run [--cluster-id <id>] [--warehouse-id <id>] [--log [name]]  Run code on Databricks"
end

return M
