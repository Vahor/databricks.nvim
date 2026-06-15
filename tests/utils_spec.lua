local utils = require("databricks._commands.utils")

describe("utils", function()
  describe("bufname", function()
    it("builds buffer name", function()
      assert.equal("Databricks_Deploy", utils.bufname("Deploy"))
    end)
  end)

  describe("resolve", function()
    it("returns string as-is", function()
      assert.equal("/tmp/venv", utils.resolve("/tmp/venv", "ENV"))
    end)

    it("calls function", function()
      assert.equal("fn-val", utils.resolve(function() return "fn-val" end, "ENV"))
    end)

    it("falls back to env var", function()
      vim.env.TEST_VAR = "env-val"
      assert.equal("env-val", utils.resolve(nil, "TEST_VAR"))
      vim.env.TEST_VAR = nil
    end)

    it("override takes highest priority", function()
      assert.equal("override", utils.resolve("default", "ENV", "override"))
    end)
  end)

  describe("merge_flags", function()
    it("CLI overrides defaults, nil does not", function()
      local r = utils.merge_flags({ force = true, target = nil }, { force = false, target = "dev" })
      assert.True(r.force)
      assert.equal("dev", r.target)
    end)
  end)

  describe("build_term_command", function()
    it("includes header with dim formatting", function()
      local r = utils.build_term_command({ "databricks", "deploy" }, nil)
      assert.truthy(r:find("databricks deploy"))
      assert.truthy(r:find(string.char(27) .. "%[2m"))
    end)

    it("includes venv info when provided", function()
      local r = utils.build_term_command({ "make" }, "/tmp/venv")
      assert.truthy(r:find("venv:"))
      assert.truthy(r:find("/tmp/venv"))
    end)
  end)
end)
