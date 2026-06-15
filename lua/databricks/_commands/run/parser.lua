local config = require("databricks.config")
local utils = require("databricks._commands.utils")
local python = require("databricks._commands.run.python")
local sql = require("databricks._commands.run.sql")

local M = {}

local function get_code()
  local prev_mode = vim.fn.mode(1)

  if prev_mode:match("^[vV\22]") then
    local start_line = vim.fn.line("'<")
    local end_line = vim.fn.line("'>")
    if start_line == 0 or end_line == 0 then
      vim.notify("databricks.nvim: no visual selection found", vim.log.levels.ERROR)
      return nil
    end

    local lines = vim.fn.getline(start_line, end_line)

    if prev_mode == "v" and start_line == end_line then
      local col_start = vim.fn.col("'<")
      local col_end = vim.fn.col("'>")
      lines[1] = lines[1]:sub(col_start, col_end)
    end

    return table.concat(lines, "\n")
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if #lines == 0 or (#lines == 1 and lines[1] == "") then
    vim.notify("databricks.nvim: empty buffer", vim.log.levels.ERROR)
    return nil
  end
  return table.concat(lines, "\n")
end

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

function M.parse(args)
  local code = get_code()
  if not code then
    return nil
  end

  local language = detect_language()
  if not language then
    vim.notify("databricks.nvim: unsupported filetype '" .. vim.bo.filetype .. "'. Supported: python, sql", vim.log.levels.ERROR)
    return nil
  end

  local opts = { language = language, code = code, cluster_id = nil, warehouse_id = nil }
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
    else
      vim.notify("databricks.nvim: unknown flag '" .. arg .. "'", vim.log.levels.ERROR)
      return nil
    end
    i = i + 1
  end

  return opts
end

function M.run(opts)
  if opts == nil then
    return
  end

  local cfg = config.config.commands.run
  local cluster_id = utils.resolve(cfg.cluster_id, "DATABRICKS_NVIM_CLUSTER_ID", opts.cluster_id)
  local warehouse_id = utils.resolve(cfg.warehouse_id, "DATABRICKS_NVIM_WAREHOUSE_ID", opts.warehouse_id)

  vim.g.databricks_run_state = "running"

  if opts.language == "python" then
    if not cluster_id then
      utils.append_to_buffer("Run", "Error: no cluster_id configured.\n  Set commands.run.cluster_id, use --cluster-id, or DATABRICKS_NVIM_CLUSTER_ID env var.\n", "ErrorMsg")
      vim.g.databricks_run_state = "error"
      return
    end
    python.run(opts.code, cluster_id)
  elseif opts.language == "sql" then
    if not warehouse_id then
      utils.append_to_buffer("Run", "Error: no warehouse_id configured. Set commands.run.warehouse_id or use --warehouse-id.\n", "ErrorMsg")
      vim.g.databricks_run_state = "error"
      return
    end
    sql.run(opts.code, warehouse_id)
  end
end

function M.help()
  return "run [--cluster-id <id>] [--warehouse-id <id>]  Run current Python or SQL file (or visual selection) on Databricks"
end

return M
