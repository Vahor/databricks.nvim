--- Cluster state helpers for run sub-commands.

local u = require("databricks._commands.run.util")

local M = {}

--- Ensure a cluster is RUNNING, starting it if terminated, polling every 3s while it starts.
---@param cluster_id string
---@param on_ready fun() Called when the cluster is RUNNING
---@param on_error fun(msg: string) Called on unrecoverable error
function M.ensure_running(cluster_id, on_ready, on_error)
  local state = { poll_timer = nil }

  local function poll()
    state.poll_timer = vim.fn.timer_start(3000, function()
      vim.schedule(function()
        u.api_call({
          "api",
          "get",
          "/api/2.0/clusters/get?cluster_id=" .. cluster_id,
        }, function(data)
          if data.state == "RUNNING" then
            vim.fn.timer_stop(state.poll_timer)
            u.log("Cluster is running.\n")
            on_ready()
          elseif data.state == "ERROR" then
            vim.fn.timer_stop(state.poll_timer)
            on_error("Cluster is in ERROR state. Cannot run.")
          elseif data.state == "TERMINATED" then
            vim.fn.timer_stop(state.poll_timer)
            start_cluster()
          end
          -- PENDING, RESIZING, RESTARTING, TERMINATING, UNKNOWN: keep polling
        end, function(msg)
          vim.fn.timer_stop(state.poll_timer)
          on_error("Failed to poll cluster: " .. msg)
        end)
      end)
    end, { ["repeat"] = -1 })
  end

  local function start_cluster()
    u.log("Starting cluster " .. cluster_id .. " ...\n")
    u.api_call({
      "api",
      "post",
      "/api/2.0/clusters/start",
      "--json",
      '{"cluster_id":"' .. cluster_id .. '"}',
    }, function()
      u.log("Cluster is starting. Waiting for it to be running...\n")
      poll()
    end, function(msg)
      on_error("Failed to start cluster: " .. msg)
    end)
  end

  local function check()
    u.log("Checking cluster " .. cluster_id .. " ...\n")
    u.api_call({
      "api",
      "get",
      "/api/2.0/clusters/get?cluster_id=" .. cluster_id,
    }, function(data)
      if data.state == "RUNNING" then
        u.log("Cluster is running.\n")
        on_ready()
      elseif data.state == "ERROR" then
        on_error("Cluster is in ERROR state. Cannot run.")
      elseif data.state == "TERMINATED" then
        start_cluster()
      else
        -- PENDING, RESIZING, RESTARTING, TERMINATING, UNKNOWN
        u.log("Cluster is " .. data.state .. ". Waiting for it to start...\n")
        poll()
      end
    end, function(msg)
      on_error("Failed to check cluster: " .. msg)
    end)
  end

  check()
end

return M
