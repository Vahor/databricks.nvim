local bundle_cache = require("databricks._commands.bundle_cache")
local config = require("databricks.config")

local function write_bundle(root, lines)
  vim.fn.writefile(lines, vim.fs.joinpath(root, "databricks.yml"))
end

describe("bundle_cache", function()
  local tmpdir
  local orig_system

  before_each(function()
    config.setup()
    bundle_cache.invalidate()
    tmpdir = vim.fn.tempname() .. "_bundle_cache_test"
    vim.fn.mkdir(tmpdir, "p")
    write_bundle(tmpdir, { "bundle:", "  name: test" })
    orig_system = vim.system
  end)

  after_each(function()
    vim.system = orig_system
    vim.fn.delete(tmpdir, "rf")
    bundle_cache.invalidate()
    config.setup()
  end)

  it("returns cached summary without re-running the command", function()
    local calls = 0
    vim.system = function(cmd)
      -- yq call from fingerprint: return empty includes
      if cmd[1] == "yq" then
        return {
          wait = function()
            return { code = 0, stdout = "[]", stderr = "" }
          end,
        }
      end
      calls = calls + 1
      return {
        wait = function()
          return { code = 0, stdout = '{"variables":{"foo":{"default":"bar"}}}', stderr = "" }
        end,
      }
    end

    local first = bundle_cache.summary({ root = tmpdir })
    local second = bundle_cache.summary({ root = tmpdir })

    assert.equal(1, calls)
    assert.same(first, second)
  end)

  it("refresh bypasses the cache", function()
    local calls = 0
    vim.system = function(cmd)
      if cmd[1] == "yq" then
        return { wait = function() return { code = 0, stdout = "[]", stderr = "" } end }
      end
      calls = calls + 1
      return {
        wait = function()
          return { code = 0, stdout = '{"call":' .. calls .. "}", stderr = "" }
        end,
      }
    end

    local first = bundle_cache.summary({ root = tmpdir })
    local second = bundle_cache.summary({ root = tmpdir, refresh = true })

    assert.equal(2, calls)
    assert.equal(1, first.call)
    assert.equal(2, second.call)
  end)

  it("invalidates when bundle files change", function()
    local calls = 0
    vim.system = function(cmd)
      if cmd[1] == "yq" then
        return { wait = function() return { code = 0, stdout = "[]", stderr = "" } end }
      end
      calls = calls + 1
      return {
        wait = function()
          return { code = 0, stdout = '{"call":' .. calls .. "}", stderr = "" }
        end,
      }
    end

    local first = bundle_cache.summary({ root = tmpdir })
    write_bundle(tmpdir, { "bundle:", "  name: test", "variables:", "  foo:", "    default: bar" })
    local second = bundle_cache.summary({ root = tmpdir })

    assert.equal(2, calls)
    assert.equal(1, first.call)
    assert.equal(2, second.call)
  end)

  it("separates cache entries by target, resources and variables share cache", function()
    local calls = 0
    vim.system = function(cmd)
      if cmd[1] == "yq" then
        return { wait = function() return { code = 0, stdout = "[]", stderr = "" } end }
      end
      calls = calls + 1
      return {
        wait = function()
          return { code = 0, stdout = '{"call":' .. calls .. "}", stderr = "" }
        end,
      }
    end

    bundle_cache.summary({ root = tmpdir, target = "dev" })
    bundle_cache.summary({ root = tmpdir, target = "prod" })
    bundle_cache.summary({ root = tmpdir, target = "dev" })

    assert.equal(2, calls)
  end)

  it("adds --force-pull when requested", function()
    local got_cmd
    vim.system = function(cmd)
      if cmd[1] == "yq" then
        return { wait = function() return { code = 0, stdout = "[]", stderr = "" } end }
      end
      got_cmd = cmd
      return {
        wait = function()
          return { code = 0, stdout = "{}", stderr = "" }
        end,
      }
    end

    bundle_cache.summary({ root = tmpdir, force_pull = true })

    assert.True(vim.list_contains(got_cmd, "--force-pull"))
  end)

  it("warms cache asynchronously without notifying on failure", function()
    local notified = false
    local orig_notify = vim.notify
    vim.notify = function()
      notified = true
    end

    vim.system = function(cmd, _, on_exit)
      if cmd[1] == "yq" then
        return { wait = function() return { code = 0, stdout = "[]", stderr = "" } end }
      end
      if on_exit then
        on_exit({ code = 1, stdout = "", stderr = "failed" })
      end
      return {}
    end

    bundle_cache.warm({ root = tmpdir })

    vim.notify = orig_notify
    assert.False(notified)
  end)
end)
