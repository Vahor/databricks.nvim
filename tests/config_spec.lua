--- Tests for databricks.config — setup and defaults.
local config = require("databricks.config")

describe("databricks.config", function()
  after_each(function()
    -- Reset to defaults
    config.setup()
  end)

  describe("setup", function()
    it("merges user options with defaults", function()
      config.setup({ auto_detect = false, dab_file = "custom.yml" })
      assert.equal(false, config.config.auto_detect)
      assert.equal("custom.yml", config.config.dab_file)
      -- Unspecified options keep defaults
      assert.is_nil(config.config.profile)
    end)

    it("handles empty opts", function()
      config.setup()
      assert.equal(true, config.config.auto_detect)
      assert.equal("databricks.yml", config.config.dab_file)
    end)

    it("handles nil opts", function()
      config.setup(nil)
      assert.equal(true, config.config.auto_detect)
    end)
  end)
end)
