local profile = require("databricks.profile")

local M = {}

-- NOTE: haven't tested any of these URLs yet, so they may be wrong

M.DISPLAY_TYPES = {
  jobs = "job",
  pipelines = "pipeline",
  dashboards = "dashboard",
  schemas = "schema",
  volumes = "volume",
  apps = "app",
  experiments = "experiment",
  clusters = "cluster",
  registered_models = "model",
  model_serving_endpoints = "endpoint",
  quality_monitors = "monitor",
}

M.URL_PATTERNS = {
  jobs = "/jobs/%s",
  pipelines = "/pipelines/%s",
  dashboards = "/dashboards/%s",
  apps = "/apps/%s",
  experiments = "/ml/experiments/%s",
  clusters = "/compute/clusters/%s",
  registered_models = "/ml/models/%s",
  model_serving_endpoints = "/ml/endpoints/%s",
  quality_monitors = "/quality-monitors/%s",
}

local function schema_url(entry)
  local parts = vim.split(entry.id, ".", { plain = true })
  if #parts >= 2 then
    return "/explore/data/" .. parts[1] .. "/" .. parts[2]
  end
  return nil
end

local function volume_url(entry)
  local parts = vim.split(entry.id, ".", { plain = true })
  if #parts >= 3 then
    return "/explore/data/" .. parts[1] .. "/" .. parts[2] .. "/" .. parts[3]
  end
  return nil
end

local SPECIAL_URLS = {
  schemas = schema_url,
  volumes = volume_url,
}

---@param host string
---@param entry {type: string, id: string|nil}
---@return string|nil
function M.resource_url(host, entry)
  if not host or not entry.id then
    return nil
  end
  local special = SPECIAL_URLS[entry.type]
  if special then
    local path = special(entry)
    return path and (host .. path) or nil
  end
  local pattern = M.URL_PATTERNS[entry.type]
  if not pattern then
    return nil
  end
  return host .. pattern:format(entry.id)
end

--- Resolve the workspace host and build a URL for a resource.
---@param entry {type: string, id: string|nil}
---@return string|nil
function M.open_url(entry)
  local host = profile.resolve_host()
  return M.resource_url(host, entry)
end

return M
