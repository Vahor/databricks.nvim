local profile = require("databricks.profile")
local config = require("databricks.config")

describe("profile", function()
  before_each(function()
    config.setup()
    vim.env.DATABRICKS_PROFILE = nil
  end)

  it("resolves from config string", function()
    config.setup({ profile = "my-profile" })
    assert.equal("my-profile", profile.resolve())
  end)

  it("resolves from env var fallback", function()
    vim.env.DATABRICKS_PROFILE = "env-profile"
    assert.equal("env-profile", profile.resolve())
  end)
end)
