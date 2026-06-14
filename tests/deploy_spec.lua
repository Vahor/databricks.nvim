--- Tests for the :Databricks deploy command.

local commands = require("databricks._commands")
local dab = require("databricks.dab")
local config = require("databricks.config")

describe("databricks._commands", function()
  local _notify = vim.notify
  local _termopen = vim.fn.termopen
  local _is_dab_project = dab.is_dab_project

  local tmpdir
  local notifications = {}
  local termopen_calls = {}
  local win_close_calls = {}
  local win_close_original

  before_each(function()
    tmpdir = vim.fn.tempname() .. "_deploy_test"
    vim.fn.mkdir(tmpdir, "p")
    vim.fn.writefile({}, tmpdir .. "/databricks.yml")
    config.setup({ dab_file = "databricks.yml" })

    notifications = {}
    termopen_calls = {}

    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end

    vim.fn.termopen = function(cmd, opts)
      table.insert(termopen_calls, { cmd = cmd, opts = opts })
      return 42
    end

    win_close_calls = {}
    win_close_original = vim.api.nvim_win_close
    vim.api.nvim_win_close = function(win, force)
      table.insert(win_close_calls, { win = win, force = force })
      return win_close_original(win, force)
    end

    dab.is_dab_project = _is_dab_project
  end)

  after_each(function()
    vim.notify = _notify
    vim.fn.termopen = _termopen
    vim.api.nvim_win_close = win_close_original
    dab.is_dab_project = _is_dab_project
    vim.fn.delete(tmpdir, "rf")
  end)

  describe(":Databricks (no subcommand)", function()
    it("shows available commands", function()
      commands.handle({})
      assert.equal(1, #notifications)
      assert.truthy(string.find(notifications[1].msg, "available commands"))
      assert.truthy(string.find(notifications[1].msg, "deploy"))
      assert.equal(vim.log.levels.INFO, notifications[1].level)
    end)
  end)

  describe(":Databricks <unknown>", function()
    it("shows error for unknown subcommand", function()
      commands.handle({ "nope" })
      assert.equal(1, #notifications)
      assert.truthy(string.find(notifications[1].msg, "unknown command"))
      assert.equal(vim.log.levels.ERROR, notifications[1].level)
    end)
  end)

  describe(":Databricks deploy outside DAB project", function()
    it("shows error when not in a DAB project", function()
      dab.is_dab_project = function() return false end

      commands.handle({ "deploy" })
      assert.equal(1, #notifications)
      assert.truthy(string.find(notifications[1].msg, "not in a DAB project"))
      assert.equal(vim.log.levels.ERROR, notifications[1].level)
      assert.equal(0, #termopen_calls)
    end)
  end)

  describe(":Databricks deploy inside DAB project", function()
    before_each(function()
      vim.fn.chdir(tmpdir)
    end)

    after_each(function()
      vim.fn.chdir(vim.fn.getcwd())
    end)

    it("calls termopen with correct command and cwd", function()
      commands.handle({ "deploy" })
      assert.equal(1, #termopen_calls)
      assert.equal("echo 'deploying...'", termopen_calls[1].cmd)
      assert.equal(vim.fn.resolve(tmpdir), vim.fn.resolve(termopen_calls[1].opts.cwd))
    end)

    it("closes terminal window on exit code 0", function()
      commands.handle({ "deploy" })
      assert.equal(1, #termopen_calls)
      local on_exit = termopen_calls[1].opts.on_exit

      on_exit(42, 0, "exit")

      -- vim.schedule runs on next event loop tick
      vim.wait(100, function() return #win_close_calls > 0 end)
      assert.equal(1, #win_close_calls)

      local success_notif = nil
      for _, n in ipairs(notifications) do
        if string.find(n.msg, "succeeded") then
          success_notif = n
        end
      end
      assert.truthy(success_notif)
      assert.equal(vim.log.levels.INFO, success_notif.level)
    end)

    it("does NOT close terminal window on non-zero exit code", function()
      commands.handle({ "deploy" })
      local on_exit = termopen_calls[1].opts.on_exit

      on_exit(42, 1, "exit")

      vim.wait(100, function() return false end)
      assert.equal(0, #win_close_calls)

      local fail_notif = nil
      for _, n in ipairs(notifications) do
        if string.find(n.msg, "failed") then
          fail_notif = n
        end
      end
      assert.truthy(fail_notif)
      assert.equal(vim.log.levels.ERROR, fail_notif.level)
    end)
  end)

  describe("completion", function()
    it("returns matching subcommands", function()
      local matches = commands.complete("de")
      assert.equal(1, #matches)
      assert.equal("deploy", matches[1])
    end)

    it("returns empty for no match", function()
      local matches = commands.complete("zzz")
      assert.equal(0, #matches)
    end)
  end)
end)
