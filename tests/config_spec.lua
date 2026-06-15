--- Tests for databricks.config — setup and defaults.
local config = require("databricks.config")

describe("databricks.config", function()
  after_each(function()
    -- Reset to defaults
    config.setup()
  end)

  describe("setup", function()
    it("merges user options with defaults", function()
      config.setup({ auto_detect = false, dab = { schema = "/local/schema.json" } })
      assert.equal(false, config.config.auto_detect)
      assert.equal("/local/schema.json", config.config.dab.schema)
      -- Unspecified options keep defaults
      assert.is_nil(config.config.profile)
    end)

    it("handles empty opts", function()
      config.setup()
      assert.equal(true, config.config.auto_detect)
    end)

    it("handles nil opts", function()
      config.setup(nil)
      assert.equal(true, config.config.auto_detect)
    end)

    it("overrides dab.schema", function()
      config.setup({ dab = { schema = "/local/schema.json" } })
      assert.equal("/local/schema.json", config.config.dab.schema)
    end)

    it("defaults venv to nil", function()
      config.setup()
      assert.is_nil(config.config.venv)
    end)

    it("accepts venv path", function()
      config.setup({ venv = "/home/user/.venv" })
      assert.equal("/home/user/.venv", config.config.venv)
    end)

    it("accepts venv as a function", function()
      local fn = function() return "/fn/venv" end
      config.setup({ venv = fn })
      assert.equal(fn, config.config.venv)
    end)

    it("accepts profile as a function", function()
      local fn = function() return "fn-profile" end
      config.setup({ profile = fn })
      assert.equal(fn, config.config.profile)
    end)
  end)
end)
