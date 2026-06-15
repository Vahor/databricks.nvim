local DAB_FILE = "databricks.yml"

local M = {}

function M.is_dab_root(dir)
  return vim.uv.fs_stat(vim.fs.joinpath(dir, DAB_FILE)) ~= nil
end

function M.find_root(path)
  return vim.fs.root(path or vim.fn.getcwd(), DAB_FILE)
end

function M.is_dab_project(path)
  return M.find_root(path) ~= nil
end

return M
