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
      assert.equal(
        "https://raw.githubusercontent.com/databricks/cli/refs/heads/main/bundle/schema/jsonschema.json",
        config.config.schema_source
      )
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

    it("overrides schema_source", function()
      config.setup({ schema_source = "/local/schema.json" })
      assert.equal("/local/schema.json", config.config.schema_source)
    end)
  end)
end)
