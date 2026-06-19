local deploy = require("databricks._commands.deploy.run")

describe("deploy parser", function()
  it("returns defaults for no arguments", function()
    local r = deploy.parse({})
    assert.same({ force = false, auto_approve = false, target = nil }, r)
  end)

  it("parses all flags", function()
    local r = deploy.parse({ "--force", "--auto-approve", "--target", "prod" })
    assert.True(r.force)
    assert.True(r.auto_approve)
    assert.equal("prod", r.target)
  end)

  it("returns nil for unknown flags", function()
    assert.is_nil(deploy.parse({ "--unknown" }))
  end)

  it("returns nil for --target without a value", function()
    assert.is_nil(deploy.parse({ "--target" }))
  end)

  it("returns nil for --target followed by another flag", function()
    assert.is_nil(deploy.parse({ "--target", "--force" }))
  end)
end)
