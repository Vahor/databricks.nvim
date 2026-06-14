--- Deploy a DAB project using `databricks bundle deploy`.

local dab = require("databricks.dab")
local utils = require("databricks._commands.utils")

local M = {}

---@param opts table Parsed options from the deploy parser
function M.run(opts)
  opts = opts or {}

  if not dab.is_dab_project() then
    vim.notify("databricks.nvim: not in a DAB project (no databricks.yml found)", vim.log.levels.ERROR)
    return
  end

  local root = dab.find_root()
  if not root then
    return
  end

  utils.run_terminal({ cmd = "echo TODO", cwd = root })
end

return M
