--- Tests for databricks._commands.run.parser — filetype detection and code extraction.
local run_parser = require("databricks._commands.run.parser")

describe("databricks._commands.run.parser", function()
  describe("help", function()
    it("returns a help string", function()
      local h = run_parser.help()
      assert.truthy(h:find("run"))
      assert.truthy(h:find("Python"))
    end)
  end)

  describe("parse", function()
    it("returns nil for unsupported filetype (empty buffer)", function()
      -- In a fresh buffer, filetype is empty
      local result = run_parser.parse({})
      assert.is_nil(result)
    end)

    it("accepts --cluster-id override", function()
      -- Can't test filetype detection in headless easily, so test flag parsing
      -- by setting filetype to python first
      vim.bo.filetype = "python"
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "print('hello')" })

      local result = run_parser.parse({ "--cluster-id", "1234-5678" })
      assert.truthy(result)
      assert.equal("python", result.language)
      assert.equal("1234-5678", result.cluster_id)
      assert.is_nil(result.warehouse_id)
    end)

    it("accepts --warehouse-id override", function()
      vim.bo.filetype = "sql"
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "SELECT 1" })

      local result = run_parser.parse({ "--warehouse-id", "abcd-efgh" })
      assert.truthy(result)
      assert.equal("sql", result.language)
      assert.equal("abcd-efgh", result.warehouse_id)
      assert.is_nil(result.cluster_id)
    end)

    it("returns nil for unknown flag", function()
      vim.bo.filetype = "python"
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x = 1" })

      local result = run_parser.parse({ "--unknown" })
      assert.is_nil(result)
    end)

    it("returns nil for --cluster-id without value", function()
      vim.bo.filetype = "python"
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x = 1" })

      local result = run_parser.parse({ "--cluster-id" })
      assert.is_nil(result)
    end)

    it("returns nil for --warehouse-id without value", function()
      vim.bo.filetype = "sql"
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "SELECT 1" })

      local result = run_parser.parse({ "--warehouse-id" })
      assert.is_nil(result)
    end)

    it("captures full file content for python", function()
      vim.bo.filetype = "python"
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "import os", "print(os.getcwd())" })

      local result = run_parser.parse({})
      assert.truthy(result)
      assert.equal("python", result.language)
      assert.equal("import os\nprint(os.getcwd())", result.code)
    end)

    it("captures full file content for sql", function()
      vim.bo.filetype = "sql"
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "SELECT *", "FROM users" })

      local result = run_parser.parse({})
      assert.truthy(result)
      assert.equal("sql", result.language)
      assert.equal("SELECT *\nFROM users", result.code)
    end)
  end)
end)
