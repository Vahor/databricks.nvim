--- DAB project detection helpers. A DAB project is identified by a `databricks.yml` file.
local DAB_FILE = "databricks.yml"

local M = {}

--- Check if a directory contains the DAB marker file.
---@param dir string
---@return boolean
function M.is_dab_root(dir)
  return vim.uv.fs_stat(vim.fs.joinpath(dir, DAB_FILE)) ~= nil
end

--- Find the nearest DAB project root walking upward from path.
---@param path string|nil (defaults to cwd)
---@return string|nil
function M.find_root(path)
  return vim.fs.root(path or vim.fn.getcwd(), DAB_FILE)
end

--- Check if the given path (or cwd) is inside a DAB project.
---@param path string|nil
---@return boolean
function M.is_dab_project(path)
  return M.find_root(path) ~= nil
end

return M
