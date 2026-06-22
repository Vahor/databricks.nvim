local utils = require("databricks._commands.utils")
local config = require("databricks.config")

describe("utils", function()
  describe("resolve", function()
    it("returns string as-is", function()
      assert.equal("/tmp/venv", utils.resolve("/tmp/venv", "ENV"))
    end)

    it("calls function", function()
      assert.equal(
        "fn-val",
        utils.resolve(function()
          return "fn-val"
        end, "ENV")
      )
    end)

    it("falls back to env var", function()
      vim.env.TEST_VAR = "env-val"
      assert.equal("env-val", utils.resolve(nil, "TEST_VAR"))
      vim.env.TEST_VAR = nil
    end)

    it("override takes highest priority", function()
      assert.equal("override", utils.resolve("default", "ENV", "override"))
    end)

    it("returns nil when value is nil and env var is unset", function()
      assert.is_nil(utils.resolve(nil, "NONEXISTENT_VAR"))
    end)

    it("returns nil when env var is empty string", function()
      vim.env.TEST_RESOLVE_EMPTY = ""
      assert.is_nil(utils.resolve(nil, "TEST_RESOLVE_EMPTY"))
      vim.env.TEST_RESOLVE_EMPTY = nil
    end)

    it("function takes precedence over env var", function()
      vim.env.TEST_RESOLVE_VAR = "env-val"
      local fn = function()
        return "fn-val"
      end
      assert.equal("fn-val", utils.resolve(fn, "TEST_RESOLVE_VAR"))
      vim.env.TEST_RESOLVE_VAR = nil
    end)

    it("config string takes precedence over env var", function()
      vim.env.TEST_RESOLVE_VAR = "env-val"
      assert.equal("cfg-val", utils.resolve("cfg-val", "TEST_RESOLVE_VAR"))
      vim.env.TEST_RESOLVE_VAR = nil
    end)
  end)

  describe("merge_flags", function()
    it("CLI overrides defaults, nil does not", function()
      local r = utils.merge_flags({ force = true, target = nil }, { force = false, target = "dev" })
      assert.True(r.force)
      assert.equal("dev", r.target)
    end)

    it("extra defaults are preserved", function()
      local r = utils.merge_flags({ force = true }, { force = false, target = "dev", auto_approve = true })
      assert.True(r.force)
      assert.equal("dev", r.target)
      assert.True(r.auto_approve)
    end)
  end)

  describe("build_env", function()
    after_each(function()
      config.setup()
      vim.env.DATABRICKS_NVIM_VENV = nil
    end)

    it("inherits process env without venv when none configured", function()
      local env = utils.build_env()
      assert.is_nil(env["VIRTUAL_ENV"])
      -- PATH should still be present from the inherited process environment
      assert.is_not_nil(env["PATH"])
      assert.is_not_nil(env["HOME"])
    end)

    it("sets VIRTUAL_ENV and prepends venv/bin to PATH from string config", function()
      config.setup({ venv = "/tmp/test-venv" })
      local env = utils.build_env()
      assert.equal("/tmp/test-venv", env["VIRTUAL_ENV"])
      assert.truthy(vim.startswith(env["PATH"], "/tmp/test-venv/bin:"))
    end)

    it("calls the venv config function", function()
      config.setup({
        venv = function()
          return "/tmp/fn-venv"
        end,
      })
      local env = utils.build_env()
      assert.equal("/tmp/fn-venv", env["VIRTUAL_ENV"])
    end)

    it("falls back to DATABRICKS_NVIM_VENV env var", function()
      vim.env.DATABRICKS_NVIM_VENV = "/tmp/env-venv"
      local env = utils.build_env()
      assert.equal("/tmp/env-venv", env["VIRTUAL_ENV"])
      assert.truthy(vim.startswith(env["PATH"], "/tmp/env-venv/bin:"))
    end)
  end)

  describe("build_term_command", function()
    it("includes header with dim formatting", function()
      local r = utils.build_term_command({ "databricks", "deploy" }, nil)
      assert.truthy(r:find("databricks deploy"))
      assert.truthy(r:find(string.char(27) .. "%[2m"))
    end)

    it("includes venv info when provided", function()
      local r = utils.build_term_command({ "make" }, "/tmp/venv")
      assert.truthy(r:find("venv:"))
      assert.truthy(r:find("/tmp/venv"))
    end)
  end)

  describe("databricks_cmd target", function()
    after_each(function()
      config.setup()
      vim.env.DATABRICKS_BUNDLE_TARGET = nil
    end)

    local function has_flag(cmd, flag)
      for _, v in ipairs(cmd) do
        if v == flag then
          return true
        end
      end
      return false
    end

    local function target_value(cmd)
      for i, v in ipairs(cmd) do
        if v == "--target" then
          return cmd[i + 1]
        end
      end
      return nil
    end

    it("omits --target when opts is not provided, even if configured", function()
      config.setup({ target = "dev" })
      local cmd = utils.databricks_cmd({ "bundle", "deploy" })
      assert.False(has_flag(cmd, "--target"))
    end)

    it("appends --target from opts.target", function()
      config.setup({ target = "dev" })
      local cmd = utils.databricks_cmd({ "bundle", "deploy" }, { target = "prod" })
      assert.equal("prod", target_value(cmd))
    end)

    it("falls back to the global config target when opts.target is nil", function()
      config.setup({ target = "dev" })
      local cmd = utils.databricks_cmd({ "bundle", "deploy" }, { target = nil })
      assert.equal("dev", target_value(cmd))
    end)

    it("resolves the target from a config function", function()
      config.setup({
        target = function()
          return "fn-target"
        end,
      })
      local cmd = utils.databricks_cmd({ "bundle", "deploy" }, {})
      assert.equal("fn-target", target_value(cmd))
    end)

    it("falls back to the DATABRICKS_BUNDLE_TARGET env var", function()
      config.setup()
      vim.env.DATABRICKS_BUNDLE_TARGET = "env-target"
      local cmd = utils.databricks_cmd({ "bundle", "deploy" }, {})
      assert.equal("env-target", target_value(cmd))
    end)

    it("opts.target overrides the env var", function()
      vim.env.DATABRICKS_BUNDLE_TARGET = "env-target"
      local cmd = utils.databricks_cmd({ "bundle", "deploy" }, { target = "prod" })
      assert.equal("prod", target_value(cmd))
    end)

    it("omits --target when neither opts nor config set it", function()
      config.setup()
      local cmd = utils.databricks_cmd({ "bundle", "deploy" }, {})
      assert.False(has_flag(cmd, "--target"))
    end)
  end)
end)
