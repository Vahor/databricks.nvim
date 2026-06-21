local deploy = require("databricks._commands.deploy.run")

describe("deploy parser", function()
  it("returns defaults for no arguments", function()
    local r = deploy.parse({})
    assert.same({ force = false, auto_approve = false }, r)
  end)

  it("parses force and auto-approve flags", function()
    local r = deploy.parse({ "--force", "--auto-approve" })
    assert.True(r.force)
    assert.True(r.auto_approve)
  end)

  it("returns nil for unknown flags", function()
    assert.is_nil(deploy.parse({ "--unknown" }))
  end)

  it("no longer parses --target itself (handled globally in _commands/init.lua)", function()
    assert.is_nil(deploy.parse({ "--target", "prod" }))
  end)
end)
