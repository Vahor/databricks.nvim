local commands = require("databricks._commands")

describe("commands global --target parser", function()
  it("extracts --target and removes it from the remaining args", function()
    local remaining, target = commands.extract_target({ "--force", "--target", "prod", "--auto-approve" })
    assert.same({ "--force", "--auto-approve" }, remaining)
    assert.equal("prod", target)
  end)

  it("returns a nil target when the flag is absent", function()
    local remaining, target = commands.extract_target({ "--force" })
    assert.same({ "--force" }, remaining)
    assert.is_nil(target)
  end)

  it("handles empty args", function()
    local remaining, target = commands.extract_target({})
    assert.same({}, remaining)
    assert.is_nil(target)
  end)

  it("returns nil args when --target has no value", function()
    local remaining = commands.extract_target({ "--target" })
    assert.is_nil(remaining)
  end)

  it("returns nil args when --target is followed by another flag", function()
    local remaining = commands.extract_target({ "--target", "--force" })
    assert.is_nil(remaining)
  end)
end)

describe("commands --target opt-in", function()
  -- Only bundle commands opt into the global --target flag; others must still
  -- reject it as an unknown flag (so typos/misconfig are caught).
  it("bundle commands accept --target", function()
    assert.True(require("databricks._commands.deploy.run").accepts_target)
    assert.True(require("databricks._commands.resources.run").accepts_target)
    assert.True(require("databricks._commands.variables.run").accepts_target)
  end)

  it("non-bundle commands do not accept --target", function()
    assert.is_nil(require("databricks._commands.run.run").accepts_target)
    assert.is_nil(require("databricks._commands.log.run").accepts_target)
  end)
end)
