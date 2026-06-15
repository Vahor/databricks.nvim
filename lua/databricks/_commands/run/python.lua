local u = require("databricks._commands.run.util")
local cluster = require("databricks._commands.run.cluster")

local M = {}

function M.run(code, cluster_id)
  local start_ns = vim.uv.hrtime()

  cluster.ensure_running(cluster_id, function()
    local s = { code = code, cluster_id = cluster_id, context_id = nil, command_id = nil, poll_timer = nil }

    local function destroy_context()
      if not s.context_id then
        return
      end
      u.api_call(
        { "api", "post", "/api/1.2/contexts/destroy", "--json", '{"clusterId":"' .. s.cluster_id .. '","contextId":"' .. s.context_id .. '"}' },
        function() end,
        function() end
      )
    end

    local function handle_result(data)
      if not data.results then
        u.log(string.format("\nDone (%.1fs).\n", (vim.uv.hrtime() - start_ns) / 1e9))
        u.set_state("idle")
        return
      end

      if data.results.resultType == "text" then
        u.write(data.results.data or "")
      elseif data.results.resultType == "error" then
        u.error("Error: " .. (data.results.summary or "unknown") .. "\n")
        u.write(data.results.cause or "")
      else
        u.write(vim.inspect(data.results))
      end

      u.log(string.format("\nDone (%.1fs).\n", (vim.uv.hrtime() - start_ns) / 1e9))
      u.set_state("idle")
    end

    local function poll()
      local url = "/api/1.2/commands/status?clusterId=" .. s.cluster_id .. "&contextId=" .. s.context_id .. "&commandId=" .. s.command_id
      u.api_call({ "api", "get", url }, function(data)
        if data.status == "Finished" then
          if s.poll_timer then vim.fn.timer_stop(s.poll_timer) end
          handle_result(data)
          destroy_context()
        elseif data.status == "Error" or data.status == "Cancelled" then
          u.error("\nExecution " .. data.status .. ".\n")
          u.set_state("error")
          if s.poll_timer then vim.fn.timer_stop(s.poll_timer) end
          destroy_context()
        end
      end, function(msg)
        u.error("Poll error: " .. msg .. "\n")
        u.set_state("error")
        if s.poll_timer then vim.fn.timer_stop(s.poll_timer) end
        destroy_context()
      end)
    end

    local function start_polling()
      vim.schedule(function()
        s.poll_timer = vim.fn.timer_start(5000, poll, { ["repeat"] = -1 })
      end)
    end

    local function execute()
      u.api_call({
        "api", "post", "/api/1.2/commands/execute", "--json",
        '{"clusterId":"' .. s.cluster_id .. '","contextId":"' .. s.context_id .. '","language":"python","command":"' .. u.json_escape(s.code) .. '"}',
      }, function(data)
        if not data.id then
          u.error("Failed: missing command id\n")
          u.set_state("error")
          return
        end
        s.command_id = data.id
        u.log("Running ...\n\n")
        start_polling()
      end, function(msg)
        u.error("Failed to execute: " .. msg .. "\n")
        u.set_state("error")
        destroy_context()
      end)
    end

    u.log("Creating execution context on cluster " .. cluster_id .. " ...\n")
    u.api_call({
      "api", "post", "/api/1.2/contexts/create", "--json",
      '{"clusterId":"' .. s.cluster_id .. '","language":"python"}',
    }, function(data)
      if not data.id then
        u.error("Failed: missing context id\n")
        u.set_state("error")
        return
      end
      s.context_id = data.id
      u.log("Context created. Executing code ...\n")
      execute()
    end, function(msg)
      u.error("Failed to create context: " .. msg .. "\n")
      u.set_state("error")
    end)
  end, function(msg)
    u.error(msg .. "\n")
    u.set_state("error")
  end)
end

return M
