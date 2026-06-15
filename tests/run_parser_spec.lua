local run = require("databricks._commands.run.parser")

describe("run parser", function()
  it("returns nil for unsupported filetype", function()
    local result = run.parse({})
    assert.is_nil(result)
  end)

  it("parses flags for python buffer", function()
    vim.bo.filetype = "python"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "print('hello')" })
    local result = run.parse({ "--cluster-id", "1234-5678" })
    assert.truthy(result)
    assert.equal("python", result.language)
    assert.equal("1234-5678", result.cluster_id)
    assert.is_nil(result.warehouse_id)
  end)
end)
