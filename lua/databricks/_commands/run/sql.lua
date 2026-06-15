--- Execute SQL on a Databricks warehouse via REST API.

local u = require("databricks._commands.run.util")
local utils = require("databricks._commands.utils")

local M = {}

--- Run SQL on a warehouse.
---@param code string
---@param warehouse_id string
function M.run(code, warehouse_id)
  u.log("Running SQL on warehouse " .. warehouse_id .. " ...\n")

  vim.system(
    { "databricks", "api", "post", "/api/2.0/sql/statements",
      "--json", '{"statement":"' .. u.json_escape(code) .. '","warehouse_id":"' .. warehouse_id .. '","wait_timeout":"30s","on_wait_timeout":"CONTINUE"}' },
    { text = true, env = utils.build_env() },
    function(result)
      if result.code ~= 0 then
        u.log("Failed: " .. (result.stderr or "unknown") .. "\n")
        u.set_state("error")
        return
      end
      local ok, data = pcall(vim.json.decode, result.stdout:gsub("%s+$", ""))
      if not ok then
        u.log("Failed to parse response: " .. result.stdout .. "\n")
        u.set_state("error")
        return
      end

      if data.status and data.status.state == "SUCCEEDED" then
        if data.result and data.result.data_array then
          for _, row in ipairs(data.result.data_array) do
            u.log(table.concat(row, "\t") .. "\n")
          end
        end
        u.log("\nDone.\n")
        u.set_state("idle")
      else
        u.log("Error: " .. (data.status and data.status.state or "unknown") .. "\n")
        if data.status and data.status.error then
          u.log(data.status.error.message or "")
        end
        u.set_state("error")
      end
    end
  )
end

return M
