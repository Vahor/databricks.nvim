local profile = require("databricks.profile")

local M = {}

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
  dashboards = "/dashboardsv3/%s/published",
  apps = "/apps-v2/app/%s/overview",
  experiments = "/ml/experiments/%s",
  clusters = "/compute/clusters/%s",
  registered_models = "/explore/data/models/%s",
  model_serving_endpoints = "/ml/endpoints/%s",
  schemas = "/explore/data/%s",
  volumes = "/explore/data/volumes/%s",
}

---@param host string
---@param entry {type: string, id: string|nil, url: string|nil}
---@return string|nil
function M.resource_url(host, entry)
  if entry.url then
    return entry.url
  end
  if not host or not entry.id then
    return nil
  end
  local pattern = M.URL_PATTERNS[entry.type]
  if not pattern then
    return nil
  end
  local dotBySlash = vim.fn.substitute(entry.id, "\\.", "/", "g")
  return host .. pattern:format(dotBySlash)
end

return M
