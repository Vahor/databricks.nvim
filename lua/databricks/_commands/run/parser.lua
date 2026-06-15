--- Parser for the `:Databricks run` subcommand.

local M = {}

---@class Databricks.RunOpts
---@field language "python"|"sql"
---@field code string The code to execute (file contents or visual selection)
---@field cluster_id string|nil Override for config cluster_id
---@field warehouse_id string|nil Override for config warehouse_id

--- Get the code to run: visual selection if active, otherwise full file contents.
---@return string|nil code, string|nil error_message
local function get_code()
  -- mode(1) returns the mode BEFORE the Ex command was invoked.
  -- vim.fn.mode() inside an Ex command always returns "n" because
  -- Vim exits visual mode before running the command.
  local prev_mode = vim.fn.mode(1)

  if prev_mode:match("^[vV\22]") then
    local start_line = vim.fn.line("'<")
    local end_line = vim.fn.line("'>")
    if start_line == 0 or end_line == 0 then
      return nil, "no visual selection found"
    end

    local lines = vim.fn.getline(start_line, end_line)

    -- For character-wise visual on a single line, trim to selected columns
    if prev_mode == "v" and start_line == end_line then
      local col_start = vim.fn.col("'<")
      local col_end = vim.fn.col("'>")
      lines[1] = lines[1]:sub(col_start, col_end)
    end

    return table.concat(lines, "\n"), nil
  end

  -- No selection: read the whole buffer
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if #lines == 0 or (#lines == 1 and lines[1] == "") then
    return nil, "empty buffer"
  end
  return table.concat(lines, "\n"), nil
end

--- Detect language from buffer filetype.
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

--- Parse CLI arguments for `:Databricks run`.
---@param args string[] Remaining arguments after the subcommand name
---@return Databricks.RunOpts|nil Parsed options, or nil on error
function M.parse(args)
  local code, err = get_code()
  if not code then
    vim.notify("databricks.nvim: " .. err, vim.log.levels.ERROR)
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

  local opts = {
    language = language,
    code = code,
    cluster_id = nil,
    warehouse_id = nil,
  }

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

---@return string
function M.help()
  return "run [--cluster-id <id>] [--warehouse-id <id>]  Run current Python or SQL file (or visual selection) on Databricks"
end

return M
