--- Tests for databricks._commands.deploy.parser — CLI argument parsing.
local deploy_parser = require("databricks._commands.deploy.parser")

describe("databricks._commands.deploy.parser", function()
  describe("parse", function()
    it("returns defaults for no arguments", function()
      local result = deploy_parser.parse({})
      assert.same({ force = false, auto_approve = false, target = nil }, result)
    end)

    it("parses --force flag", function()
      local result = deploy_parser.parse({ "--force" })
      assert.True(result.force)
      assert.False(result.auto_approve)
      assert.is_nil(result.target)
    end)

    it("parses --auto-approve flag", function()
      local result = deploy_parser.parse({ "--auto-approve" })
      assert.True(result.auto_approve)
      assert.False(result.force)
      assert.is_nil(result.target)
    end)

    it("parses --target with value", function()
      local result = deploy_parser.parse({ "--target", "dev" })
      assert.equal("dev", result.target)
      assert.False(result.force)
      assert.False(result.auto_approve)
    end)

    it("parses multiple flags together", function()
      local result = deploy_parser.parse({ "--force", "--auto-approve", "--target", "prod" })
      assert.True(result.force)
      assert.True(result.auto_approve)
      assert.equal("prod", result.target)
    end)

    it("returns nil for --target without a value", function()
      local result = deploy_parser.parse({ "--target" })
      assert.is_nil(result)
    end)

    it("returns nil for --target followed by another flag", function()
      local result = deploy_parser.parse({ "--target", "--force" })
      assert.is_nil(result)
    end)

    it("returns nil for unknown flags", function()
      local result = deploy_parser.parse({ "--unknown" })
      assert.is_nil(result)
    end)

    it("handles empty string arguments (ignores them)", function()
      -- When nvim passes empty string as args, parser should handle gracefully
      -- Actually empty strings won't match any flag, so they'd trigger "unknown flag"
      -- Let's check: empty string doesn't start with "-"
      local result = deploy_parser.parse({ "" })
      assert.is_nil(result, "empty string should be treated as unknown flag")
    end)
  end)

  describe("help", function()
    it("returns a help string", function()
      local h = deploy_parser.help()
      assert.truthy(h)
      assert.truthy(h:find("deploy"))
      assert.truthy(h:find("databricks bundle deploy"))
    end)
  end)
end)
