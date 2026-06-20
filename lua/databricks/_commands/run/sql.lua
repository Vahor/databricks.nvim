local u = require("databricks._commands.run.util")
local profile = require("databricks.profile")

local M = {}

--- Run SQL on a Databricks warehouse via the SQL Statement Execution API.
--- Renders result rows as tab-separated values in the output buffer.
---@param code string
---@param warehouse_id string
function M.run(code, warehouse_id)
  local start_ns = vim.uv.hrtime()

  local host = profile.resolve_host()
  if host then
    local url = host .. "/sql/history/" .. warehouse_id
    u.log("Open in browser: " .. url .. "\n")
  end

  u.log("Running SQL on warehouse " .. warehouse_id .. " ...\n")

  u.api_call({
    "api",
    "post",
    "/api/2.0/sql/statements",
    "--json",
    '{"statement":"'
      .. u.json_escape(code)
      .. '","warehouse_id":"'
      .. warehouse_id
      .. '","wait_timeout":"30s","on_wait_timeout":"CONTINUE"}',
  }, function(data)
    if data.status and data.status.state == "SUCCEEDED" then
      if data.result and data.result.data_array then
        for _, row in ipairs(data.result.data_array) do
          u.write(table.concat(row, "\t") .. "\n")
        end
      end
      u.log(string.format("\nDone (%.1fs).\n", (vim.uv.hrtime() - start_ns) / 1e9))
      u.set_state("idle")
    else
      u.error("Error: " .. (data.status and data.status.state or "unknown") .. "\n")
      if data.status and data.status.error then
        u.write(data.status.error.message or "")
      end
      u.set_state("error")
    end
  end, function(msg)
    u.error("Failed: " .. msg .. "\n")
    u.set_state("error")
  end)
end

return M
