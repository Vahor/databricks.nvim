local u = require("databricks._commands.run.util")

local M = {}

function M.ensure_running(cluster_id, on_ready, on_error)
  local poll_timer = nil

  local function check()
    u.log("Checking cluster " .. cluster_id .. " ...\n")
    u.api_call({ "api", "get", "/api/2.0/clusters/get?cluster_id=" .. cluster_id }, function(data)
      if data.state == "RUNNING" then
        u.log("Cluster is running.\n")
        on_ready()
      elseif data.state == "ERROR" then
        on_error("Cluster is in ERROR state. Cannot run.")
      elseif data.state == "TERMINATED" then
        start_cluster()
      else
        u.log("Cluster is " .. data.state .. ". Waiting for it to start...\n")
        schedule_poll()
      end
    end, function(msg)
      on_error("Failed to check cluster: " .. msg)
    end)
  end

  local function poll()
    poll_timer = vim.fn.timer_start(5000, function()
      u.api_call({ "api", "get", "/api/2.0/clusters/get?cluster_id=" .. cluster_id }, function(data)
        if data.state == "RUNNING" then
          if poll_timer then vim.fn.timer_stop(poll_timer) end
          u.log("Cluster is running.\n")
          on_ready()
        elseif data.state == "ERROR" then
          if poll_timer then vim.fn.timer_stop(poll_timer) end
          on_error("Cluster is in ERROR state. Cannot run.")
        elseif data.state == "TERMINATED" then
          if poll_timer then vim.fn.timer_stop(poll_timer) end
          start_cluster()
        end
      end, function(msg)
        if poll_timer then vim.fn.timer_stop(poll_timer) end
        on_error("Failed to poll cluster: " .. msg)
      end)
    end, { ["repeat"] = -1 })
  end

  local function schedule_poll()
    vim.schedule(poll)
  end

  local function start_cluster()
    u.log("Starting cluster " .. cluster_id .. " ...\n")
    u.api_call({ "api", "post", "/api/2.0/clusters/start", "--json", '{"cluster_id":"' .. cluster_id .. '"}' }, function()
      u.log("Cluster is starting. Waiting for it to be running...\n")
      schedule_poll()
    end, function(msg)
      on_error("Failed to start cluster: " .. msg)
    end)
  end

  check()
end

return M
