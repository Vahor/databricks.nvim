--- Execute Python code on a Databricks cluster via REST API.

local u = require("databricks._commands.run.util")

local M = {}

---@class PythonRunState
---@field code string
---@field cluster_id string
---@field context_id string|nil
---@field command_id string|nil
---@field poll_timer integer|nil

--- Destroy the execution context if it was created. Called on every exit path.
local function step_destroy_context(s)
  if not s.context_id then return end
  u.api_call(
    { "databricks", "api", "post", "/api/2.0/contexts/destroy",
      "--json", '{"clusterId":"' .. s.cluster_id .. '","contextId":"' .. s.context_id .. '"}' },
    function() end,
    function() end -- best-effort, ignore errors
  )
end

-- Step functions: each handles one async API call, passing state to the next.

local function step_create_context(s)
  u.log("Creating execution context on cluster " .. s.cluster_id .. " ...\n")
  u.api_call(
    { "databricks", "api", "post", "/api/2.0/contexts/create",
      "--json", '{"clusterId":"' .. s.cluster_id .. '","language":"python"}' },
    function(data)
      if not data.id then
        u.log("Failed: missing context id\n")
        u.set_state("error")
        return
      end
      s.context_id = data.id
      u.log("Context created. Executing code ...\n")
      step_execute(s)
    end,
    function(msg)
      u.log("Failed to create context: " .. msg .. "\n")
      u.set_state("error")
    end
  )
end

local function step_execute(s)
  u.api_call(
    { "databricks", "api", "post", "/api/2.0/commands/execute",
      "--json", '{"clusterId":"' .. s.cluster_id .. '","contextId":"' .. s.context_id .. '","language":"python","command":"' .. u.json_escape(s.code) .. '"}' },
    function(data)
      if not data.id then
        u.log("Failed: missing command id\n")
        u.set_state("error")
        return
      end
      s.command_id = data.id
      u.log("Running ...\n\n")
      step_start_polling(s)
    end,
    function(msg)
      u.log("Failed to execute: " .. msg .. "\n")
      u.set_state("error")
      step_destroy_context(s)
    end
  )
end

local function step_start_polling(s)
  s.poll_timer = vim.fn.timer_start(1000, function()
    vim.schedule(function() step_poll(s) end)
  end, { ["repeat"] = -1 })
end

local function step_poll(s)
  local url = "/api/2.0/commands/status?clusterId=" .. s.cluster_id
    .. "&contextId=" .. s.context_id
    .. "&commandId=" .. s.command_id

  u.api_call(
    { "databricks", "api", "get", url },
    function(data)
      if data.status == "Finished" then
        step_handle_result(data)
        vim.fn.timer_stop(s.poll_timer)
        step_destroy_context(s)
      elseif data.status == "Error" or data.status == "Cancelled" then
        u.log("\nExecution " .. data.status .. ".\n")
        u.set_state("error")
        vim.fn.timer_stop(s.poll_timer)
        step_destroy_context(s)
      end
    end,
    function(msg)
      u.log("Poll error: " .. msg .. "\n")
      u.set_state("error")
      vim.fn.timer_stop(s.poll_timer)
      step_destroy_context(s)
    end
  )
end

local function step_handle_result(data)
  if not data.results then
    u.log("\nDone.\n")
    u.set_state("idle")
    return
  end
  if data.results.resultType == "text" then
    u.log(data.results.data or "")
  elseif data.results.resultType == "error" then
    u.log("Error: " .. (data.results.summary or "unknown") .. "\n")
    u.log(data.results.cause or "")
  else
    u.log(vim.inspect(data.results))
  end
  u.log("\nDone.\n")
  u.set_state("idle")
end

--- Run Python code on a cluster.
---@param code string
---@param cluster_id string
function M.run(code, cluster_id)
  step_create_context({ code = code, cluster_id = cluster_id })
end

return M
