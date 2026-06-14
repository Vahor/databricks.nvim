--- Tests for databricks.config — commands config defaults.
local config = require("databricks.config")

describe("databricks.config commands", function()
  after_each(function()
    config.setup()
  end)

  describe("commands.deploy defaults", function()
    it("has deploy config with safe defaults", function()
      config.setup()
      local d = config.config.commands.deploy
      assert.equal(false, d.force)
      assert.equal(false, d.auto_approve)
      assert.is_nil(d.target)
    end)

    it("allows overriding deploy config", function()
      config.setup({
        commands = {
          deploy = {
            force = true,
            auto_approve = true,
            target = "dev",
          },
        },
      })
      local d = config.config.commands.deploy
      assert.True(d.force)
      assert.True(d.auto_approve)
      assert.equal("dev", d.target)
    end)

    it("partial overrides keep other defaults", function()
      config.setup({
        commands = {
          deploy = { target = "staging" },
        },
      })
      local d = config.config.commands.deploy
      assert.equal(false, d.force)
      assert.equal(false, d.auto_approve)
      assert.equal("staging", d.target)
    end)
  end)

  describe("commands.run defaults", function()
    it("has run config with nil defaults", function()
      config.setup()
      local r = config.config.commands.run
      assert.is_nil(r.cluster_id)
      assert.is_nil(r.warehouse_id)
    end)

    it("allows overriding run config", function()
      config.setup({
        commands = {
          run = {
            cluster_id = "1234-5678",
            warehouse_id = "abcd-efgh",
          },
        },
      })
      local r = config.config.commands.run
      assert.equal("1234-5678", r.cluster_id)
      assert.equal("abcd-efgh", r.warehouse_id)
    end)
  end)
end)
