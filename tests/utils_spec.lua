--- Tests for databricks._commands.utils — buffer naming, terminal, and flag merging.
local utils = require("databricks._commands.utils")

describe("databricks._commands.utils", function()
  describe("bufname", function()
    it("builds the full buffer name", function()
      assert.equal("Databricks_Deploy", utils.bufname("Deploy"))
      assert.equal("Databricks_Destroy", utils.bufname("Destroy"))
    end)
  end)

  describe("_create_terminal_buffer", function()
    it("creates a buffer with the correct name suffix", function()
      local buf, _ = utils._create_terminal_buffer({
        name = "Deploy",
        cmd = "echo hello",
        cwd = "/tmp",
      })
      assert.truthy(buf)
      local bname = vim.api.nvim_buf_get_name(buf)
      -- neovim may prepend cwd; match the suffix
      assert.truthy(bname:match("Databricks_Deploy$"), ("expected suffix in '%s'"):format(bname))
    end)

    it("cleans up an existing buffer with the same name", function()
      local buf1, _ = utils._create_terminal_buffer({ name = "CleanupTest", cmd = "echo", cwd = "/tmp" })

      local found = false
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if b == buf1 then found = true end
      end
      assert.True(found, "first buffer should exist")

      local buf2, _ = utils._create_terminal_buffer({ name = "CleanupTest", cmd = "echo", cwd = "/tmp" })
      assert.Not.equal(buf1, buf2, "should create a new buffer")

      local first_still_exists = false
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if b == buf1 then first_still_exists = true end
      end
      assert.False(first_still_exists, "old buffer should be deleted")
    end)

    it("defaults name to 'Terminal' when not provided", function()
      local buf, _ = utils._create_terminal_buffer({ cmd = "echo", cwd = "/tmp" })
      local bname = vim.api.nvim_buf_get_name(buf)
      assert.truthy(bname:match("Databricks_Terminal$"), ("expected suffix in '%s'"):format(bname))
    end)

    it("opens a window for the buffer", function()
      local buf, win = utils._create_terminal_buffer({ name = "WinTest", cmd = "echo", cwd = "/tmp" })
      assert.truthy(buf)
      assert.is_number(win)
    end)
  end)

  describe("build_term_command", function()
    it("returns a shell command with dim # for table cmd without venv", function()
      local result = utils.build_term_command({ "databricks", "deploy" }, nil)
      assert.equal("printf '%s\\n' '\x1b[2m#\x1b[0m databricks deploy' '' && exec databricks deploy", result)
    end)

    it("includes colored venv in header", function()
      local result = utils.build_term_command({ "make" }, "/tmp/venv")
      assert.equal("printf '%s\\n' '\x1b[2m#\x1b[0m \x1b[2mvenv:\x1b[0m \x1b[36m/tmp/venv\x1b[0m \x1b[2m|\x1b[0m make' '' && exec make", result)
    end)

    it("handles string cmd", function()
      local result = utils.build_term_command("make test", nil)
      assert.equal("printf '%s\\n' '\x1b[2m#\x1b[0m make test' '' && exec make test", result)
    end)
  end)

  describe("resolve", function()
    it("returns a string value as-is", function()
      assert.equal("/tmp/my-venv", utils.resolve("/tmp/my-venv", "MY_ENV_VAR"))
    end)

    it("calls a function value", function()
      local fn = function() return "/tmp/fn-venv" end
      assert.equal("/tmp/fn-venv", utils.resolve(fn, "MY_ENV_VAR"))
    end)

    it("falls back to env var when value is nil", function()
      vim.env.TEST_RESOLVE_VAR = "env-val"
      assert.equal("env-val", utils.resolve(nil, "TEST_RESOLVE_VAR"))
      vim.env.TEST_RESOLVE_VAR = nil
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
      vim.env.TEST_RESOLVE_VAR2 = "env-val"
      local fn = function() return "fn-val" end
      assert.equal("fn-val", utils.resolve(fn, "TEST_RESOLVE_VAR2"))
      vim.env.TEST_RESOLVE_VAR2 = nil
    end)

    it("env var takes precedence over config string", function()
      vim.env.TEST_RESOLVE_VAR3 = "env-val"
      assert.equal("env-val", utils.resolve("cfg-val", "TEST_RESOLVE_VAR3"))
      vim.env.TEST_RESOLVE_VAR3 = nil
    end)

    it("override takes highest priority over everything", function()
      vim.env.TEST_RESOLVE_VAR4 = "env-val"
      local fn = function() return "fn-val" end
      assert.equal("cli-val", utils.resolve(fn, "TEST_RESOLVE_VAR4", "cli-val"))
      assert.equal("cli-val", utils.resolve("cfg-val", "TEST_RESOLVE_VAR4", "cli-val"))
      vim.env.TEST_RESOLVE_VAR4 = nil
    end)
  end)

  describe("build_env", function()
    local config = require("databricks.config")

    after_each(function()
      config.setup()
      vim.env.DATABRICKS_NVIM_VENV = nil
    end)

    it("returns current env without venv when none configured", function()
      local env = utils.build_env()
      assert.is_nil(env["VIRTUAL_ENV"])
      assert.truthy(env["PATH"])
    end)

    it("sets VIRTUAL_ENV and prepends venv/bin to PATH from string config", function()
      config.setup({ venv = "/tmp/test-venv" })
      local env = utils.build_env()
      assert.equal("/tmp/test-venv", env["VIRTUAL_ENV"])
      assert.truthy(vim.startswith(env["PATH"], "/tmp/test-venv/bin:"))
    end)

    it("calls the venv config function", function()
      config.setup({ venv = function() return "/tmp/fn-venv" end })
      local env = utils.build_env()
      assert.equal("/tmp/fn-venv", env["VIRTUAL_ENV"])
    end)

    it("falls back to DATABRICKS_NVIM_VENV env var", function()
      vim.env.DATABRICKS_NVIM_VENV = "/tmp/env-venv"
      local env = utils.build_env()
      assert.equal("/tmp/env-venv", env["VIRTUAL_ENV"])
      assert.truthy(vim.startswith(env["PATH"], "/tmp/env-venv/bin:"))
    end)

    it("env var takes precedence over config string", function()
      vim.env.DATABRICKS_NVIM_VENV = "/tmp/env-venv"
      config.setup({ venv = "/tmp/cfg-venv" })
      local env = utils.build_env()
      assert.equal("/tmp/env-venv", env["VIRTUAL_ENV"])
    end)

    it("function takes precedence over env var", function()
      vim.env.DATABRICKS_NVIM_VENV = "/tmp/env-venv"
      config.setup({ venv = function() return "/tmp/fn-venv" end })
      local env = utils.build_env()
      assert.equal("/tmp/fn-venv", env["VIRTUAL_ENV"])
    end)
  end)

  describe("merge_flags", function()
    it("returns defaults when parsed is empty", function()
      local result = utils.merge_flags({}, { force = true, target = "dev" })
      assert.True(result.force)
      assert.equal("dev", result.target)
    end)

    it("CLI values override defaults", function()
      local result = utils.merge_flags(
        { force = true, target = "prod" },
        { force = false, target = "dev", auto_approve = false }
      )
      assert.True(result.force)
      assert.equal("prod", result.target)
      assert.False(result.auto_approve) -- from defaults
    end)

    it("nil in parsed does not override defaults", function()
      local result = utils.merge_flags(
        { force = false, target = nil },
        { force = true, target = "staging" }
      )
      assert.False(result.force)
      assert.equal("staging", result.target) -- defaults kept because parsed was nil
    end)

    it("extra defaults are preserved", function()
      local result = utils.merge_flags(
        { force = true },
        { force = false, target = "dev", auto_approve = true }
      )
      assert.True(result.force)
      assert.equal("dev", result.target)
      assert.True(result.auto_approve)
    end)
  end)
end)
