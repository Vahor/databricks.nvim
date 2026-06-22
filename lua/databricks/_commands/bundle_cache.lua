local config = require("databricks.config")
local dab = require("databricks.dab")
local profile = require("databricks.profile")
local utils = require("databricks._commands.utils")

local M = {}

local cache = {}

local function fingerprint(root)
  local files = dab.get_bundle_files(root)
  table.sort(files)

  local parts = {}
  for _, file in ipairs(files) do
    table.insert(parts, file .. ":" .. vim.uv.fs_stat(file).mtime.nsec)
  end
  return table.concat(parts, "|")
end

local function resolved_target(target)
  return utils.resolve(config.config.target, "DATABRICKS_BUNDLE_TARGET", target)
end

local function cache_key(opts, target)
  return table.concat({
    opts.root,
    target or "",
    profile.resolve() or "",
  }, "\n")
end

local function summary_args(opts)
  local args = { "bundle", "summary", "--include-locations" }
  if opts.force_pull then
    table.insert(args, "--force-pull")
  end
  return args
end

---@param opts {root: string, target?: string, refresh?: boolean, force_pull?: boolean}
---@return table|nil
---
--- Always runs `bundle summary --include-locations` so both resources and variables share the same cache.
--- Variables simply ignores `__locations`.
--- Accepts valid JSON even when the CLI exits non-zero (e.g. required variables unset).
function M.summary(opts)
  local target = resolved_target(opts.target)
  local key = cache_key(opts, target)
  local fp = fingerprint(opts.root)
  local cached = cache[key]

  if cached and not opts.refresh and not opts.force_pull and cached.fingerprint == fp then
    return cached.data
  end

  local data = utils.databricks_cmd_json(summary_args(opts), {
    cwd = opts.root,
    target = target,
    silent = true,
    allow_nonzero_json = true,
  })

  if not data then
    -- Already notified by databricks_cmd_json if silent is false.
    return nil
  end

  cache[key] = { fingerprint = fp, data = data }
  return data
end

---@param opts {root: string, target?: string, force_pull?: boolean}
function M.warm(opts)
  local target = resolved_target(opts.target)
  local key = cache_key(opts, target)
  local fp = fingerprint(opts.root)
  local cached = cache[key]
  if cached and cached.fingerprint == fp then
    return
  end

  utils.databricks_cmd_json_async(summary_args(opts), { cwd = opts.root, target = target }, function(data)
    if not data then
      return
    end
    cache[key] = { fingerprint = fp, data = data }
  end)
end

function M.invalidate()
  cache = {}
end

return M
