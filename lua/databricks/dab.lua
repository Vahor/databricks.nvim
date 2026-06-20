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

--- Find all YAML files belonging to a DAB project.
--- (glob search of include array in databricks.yml)
---@param root string
---@return string[]
function M.get_bundle_files(root)
  local files = { vim.fs.joinpath(root, DAB_FILE) }
  local ok, json_str = pcall(vim.fn.system, { "yq", "-o=json", ".include // []", files[1] })
  if ok and vim.v.shell_error == 0 then
    local ok2, includes = pcall(vim.json.decode, json_str)
    if ok2 and type(includes) == "table" then
      for _, pattern in ipairs(includes) do
        local matches = vim.fn.glob(vim.fs.joinpath(root, pattern), false, true)
        for _, match in ipairs(matches) do
          if not vim.tbl_contains(files, match) then
            table.insert(files, match)
          end
        end
      end
    end
  end
  return files
end

--- Scan bundle YAML files for variable definition locations.
---@param files string[]
---@return table<string, {path: string, line: integer}>
function M.find_variable_definitions(files)
  local defs = {}
  for _, fp in ipairs(files) do
    local ok, lines = pcall(vim.fn.readfile, fp)
    if ok then
      local in_variables = false
      local base_indent = nil
      for i, line in ipairs(lines) do
        if not in_variables then
          if line:match("^variables:") then
            in_variables = true
          end
        else
          if not line:match("^%s") and line ~= "" then
            break
          end
          local indent, name = line:match("^(%s+)([%w_-]+):")
          if indent and name then
            if not base_indent then
              base_indent = #indent
            end
            if #indent == base_indent and not defs[name] then
              defs[name] = { path = fp, line = i }
            end
          end
        end
      end
    end
  end
  return defs
end

return M
