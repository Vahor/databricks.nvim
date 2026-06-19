local run = require("databricks._commands.run.run")

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

  it("parses --warehouse-id for sql buffer", function()
    vim.bo.filetype = "sql"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "SELECT 1" })
    local result = run.parse({ "--warehouse-id", "abcd-efgh" })
    assert.truthy(result)
    assert.equal("sql", result.language)
    assert.equal("abcd-efgh", result.warehouse_id)
    assert.is_nil(result.cluster_id)
  end)

  it("returns nil for unknown flag", function()
    vim.bo.filetype = "python"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x = 1" })
    assert.is_nil(run.parse({ "--unknown" }))
  end)

  it("returns nil for --cluster-id without value", function()
    vim.bo.filetype = "python"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x = 1" })
    assert.is_nil(run.parse({ "--cluster-id" }))
  end)

  it("captures full file content for python", function()
    vim.bo.filetype = "python"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "import os", "print(os.getcwd())" })
    local result = run.parse({})
    assert.truthy(result)
    assert.equal("python", result.language)
    assert.equal("import os\nprint(os.getcwd())", result.code)
  end)

  it("parses --log flag without value (boolean)", function()
    vim.bo.filetype = "python"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x = 1" })
    local result = run.parse({ "--log" })
    assert.truthy(result)
    assert.is_true(result.log_name)
  end)

  it("parses --log flag with custom name", function()
    vim.bo.filetype = "python"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x = 1" })
    local result = run.parse({ "--log", "my_debug" })
    assert.truthy(result)
    assert.equal("my_debug", result.log_name)
  end)

  it("parses --log combined with --cluster-id", function()
    vim.bo.filetype = "python"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x = 1" })
    local result = run.parse({ "--log", "debug", "--cluster-id", "1234" })
    assert.truthy(result)
    assert.equal("debug", result.log_name)
    assert.equal("1234", result.cluster_id)
  end)

  it("parses --log as the last arg with no value (boolean)", function()
    vim.bo.filetype = "python"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x = 1" })
    local result = run.parse({ "--cluster-id", "1234", "--log" })
    assert.truthy(result)
    assert.is_true(result.log_name)
    assert.equal("1234", result.cluster_id)
  end)
end)
