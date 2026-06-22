local commands = require("databricks._commands")
local config = require("databricks.config")

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

  it("resources and variables parse --refresh", function()
    assert.same({ refresh = true }, require("databricks._commands.resources.run").parse({ "--refresh" }))
    assert.same({ refresh = true }, require("databricks._commands.variables.run").parse({ "--refresh" }))
  end)
end)

describe("commands handle (commands without a parse method)", function()
  local resources = require("databricks._commands.resources.run")
  local orig_run

  before_each(function()
    config.setup()
    orig_run = resources.run
  end)

  after_each(function()
    resources.run = orig_run
    config.setup()
  end)

  it("notifies an unknown flag and does not run", function()
    local ran = false
    resources.run = function()
      ran = true
    end
    local messages = {}
    local orig_notify = vim.notify
    vim.notify = function(msg)
      table.insert(messages, msg)
    end

    commands.handle({ "resources", "--bogus" })

    vim.notify = orig_notify
    assert.is_false(ran)
    local found = false
    for _, m in ipairs(messages) do
      if type(m) == "string" and m:find("unknown flag") then
        found = true
      end
    end
    assert.is_true(found)
  end)

  it("runs with empty opts when no extra args are given", function()
    local got
    resources.run = function(opts)
      got = opts
    end
    commands.handle({ "resources" })
    assert.is_table(got)
  end)

  it("passes --refresh to parse-less bundle command opts", function()
    local got
    resources.run = function(opts)
      got = opts
    end
    commands.handle({ "resources", "--refresh" })
    assert.equal(true, got and got.refresh)
  end)

  it("injects the global --target into a bundle command", function()
    local got
    resources.run = function(opts)
      got = opts
    end
    commands.handle({ "resources", "--target", "dev" })
    assert.equal("dev", got and got.target)
  end)

  it("combines --target and --refresh", function()
    local got
    resources.run = function(opts)
      got = opts
    end
    commands.handle({ "resources", "--target", "dev", "--refresh" })
    assert.equal("dev", got and got.target)
    assert.equal(true, got and got.refresh)
  end)
end)
