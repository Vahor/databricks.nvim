--- Execute SQL on a Databricks warehouse via REST API.

local u = require("databricks._commands.run.util")

local M = {}

--- Run SQL on a warehouse.
---@param code string
---@param warehouse_id string
function M.run(code, warehouse_id)
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
      u.log("\nDone.\n")
      u.set_state("idle")
    else
      u.log("Error: " .. (data.status and data.status.state or "unknown") .. "\n")
      if data.status and data.status.error then
        u.write(data.status.error.message or "")
      end
      u.set_state("error")
    end
  end, function(msg)
    u.log("Failed: " .. msg .. "\n")
    u.set_state("error")
  end)
end

return M
