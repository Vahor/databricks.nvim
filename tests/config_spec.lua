local config = require("databricks.config")

describe("config", function()
  before_each(function()
    config.setup()
  end)

  it("merges user opts with defaults", function()
    config.setup({ auto_detect = false, dab = { schema = "/local/schema.json" } })
    assert.equal(false, config.config.auto_detect)
    assert.equal("/local/schema.json", config.config.dab.schema)
    assert.is_nil(config.config.profile)
  end)

  it("accepts functions for profile and venv", function()
    config.setup({
      profile = function()
        return "fn-profile"
      end,
      venv = function()
        return "/fn/venv"
      end,
    })
    assert.equal("function", type(config.config.profile))
    assert.equal("function", type(config.config.venv))
  end)

  it("handles empty opts", function()
    config.setup({})
    assert.equal(true, config.config.auto_detect)
  end)

  it("handles nil opts", function()
    config.setup(nil)
    assert.equal(true, config.config.auto_detect)
  end)

  it("defaults venv to nil", function()
    assert.is_nil(config.config.venv)
  end)

  it("accepts venv path", function()
    config.setup({ venv = "/home/user/.venv" })
    assert.equal("/home/user/.venv", config.config.venv)
  end)

  it("accepts venv as a function", function()
    local fn = function()
      return "/fn/venv"
    end
    config.setup({ venv = fn })
    assert.equal(fn, config.config.venv)
  end)

  it("accepts cluster_id string", function()
    config.setup({ commands = { run = { cluster_id = "1234-5678" } } })
    assert.equal("1234-5678", config.config.commands.run.cluster_id)
  end)

  it("accepts warehouse_id string", function()
    config.setup({ commands = { run = { warehouse_id = "abcd-efgh" } } })
    assert.equal("abcd-efgh", config.config.commands.run.warehouse_id)
  end)
end)
