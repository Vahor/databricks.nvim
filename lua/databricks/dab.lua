--- A DAB project is identified by a `databricks.yml` file in the project root.
local config = require("databricks.config")

local M = {}

--- Check if a directory contains the DAB marker file.
--- @param dir string Directory path to check
--- @return boolean
function M.is_dab_root(dir)
  local path = vim.fs.joinpath(dir, config.config.dab_file)
  return vim.uv.fs_stat(path) ~= nil
end

--- Find the nearest DAB project root from the given path (walks upward).
--- @param path string|nil Starting path (defaults to cwd)
--- @return string|nil The root directory containing the DAB marker, or nil
function M.find_root(path)
  path = path or vim.fn.getcwd()
  return vim.fs.root(path, config.config.dab_file)
end

--- Check if the current working directory (or given path) is inside a DAB project.
--- @param path string|nil Starting path (defaults to cwd)
--- @return boolean
function M.is_dab_project(path)
  return M.find_root(path) ~= nil
end

return M
