--- Tests for databricks.profile — profile resolution.
local profile = require("databricks.profile")
local config = require("databricks.config")

describe("databricks.profile", function()
  after_each(function()
    config.setup()
  end)

  describe("resolve", function()
    it("returns the configured profile", function()
      config.setup({ profile = "my-profile" })
      assert.equal("my-profile", profile.resolve())
    end)

    it("returns nil when no profile is configured", function()
      assert.is_nil(profile.resolve())
    end)
  end)
end)
