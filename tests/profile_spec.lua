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

  it("calls the configured profile function", function()
    config.setup({
      profile = function()
        return "dynamic-profile"
      end,
    })
    assert.equal("dynamic-profile", profile.resolve())
  end)

  it("config string takes precedence over env var", function()
    vim.env.DATABRICKS_PROFILE = "env-profile"
    config.setup({ profile = "cfg-profile" })
    assert.equal("cfg-profile", profile.resolve())
  end)

  it("function takes precedence over env var", function()
    vim.env.DATABRICKS_PROFILE = "env-profile"
    config.setup({
      profile = function()
        return "fn-profile"
      end,
    })
    assert.equal("fn-profile", profile.resolve())
  end)

  it("returns nil when no profile is configured and no env var", function()
    assert.is_nil(profile.resolve())
  end)
end)
