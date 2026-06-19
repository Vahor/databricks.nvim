local logfile = require("databricks._commands.run.log")
local log_cmd = require("databricks._commands.log.run")

local LOG_DIR = vim.fn.stdpath("data") .. "/databricks.nvim"

describe("run log", function()
  before_each(function()
    logfile.close_run()
    vim.fn.system({ "rm", "-rf", LOG_DIR })
  end)

  after_each(function()
    logfile.close_run()
    vim.fn.system({ "rm", "-rf", LOG_DIR })
  end)

  describe("start_run", function()
    it("creates a log file with header", function()
      local path = logfile.start_run("python", "my-profile", "test.py")
      assert.truthy(path)
      assert.truthy(path:match("test%.py%.log$"))
      assert.truthy(vim.startswith(path, LOG_DIR))

      local f = io.open(path, "r")
      assert.truthy(f)
      local first_line = f:read("*l")
      f:close()

      assert.truthy(first_line:match("my%-profile"))
      assert.truthy(first_line:match("python"))
    end)

    it("uses unknown for nil source", function()
      local path = logfile.start_run("sql", nil)
      assert.truthy(path)
      assert.truthy(path:match("unknown%.log$"))
    end)

    it("uses source-based name when log_name is boolean true (same as default)", function()
      local path = logfile.start_run("python", "p", "mymod.py", true)
      assert.truthy(path)
      assert.truthy(path:match("mymod%.py%.log$"))
    end)

    it("uses custom name when log_name is a string", function()
      local path = logfile.start_run("python", "p", "ignored.py", "my_debug")
      assert.truthy(path)
      assert.truthy(path:match("my_debug%.log$"))
    end)

    it("overwrites file on repeated calls with same log_name", function()
      local p1 = logfile.start_run("python", "p", "src.py", "reusable")
      logfile.write("first run\n")
      logfile.close_run()

      local p2 = logfile.start_run("python", "p", "src.py", "reusable")
      logfile.write("second run\n")
      logfile.close_run()

      assert.equal(p1, p2)
      local content = table.concat(vim.fn.readfile(p1), "\n")
      assert.truthy(content:match("second run"))
      assert.falsy(content:match("first run"))
    end)
  end)

  describe("log/write/error", function()
    it("appends log messages with ANSI dim", function()
      local path = logfile.start_run("python", "test", "foo.py")
      logfile.log("hello\n")
      logfile.close_run()

      local content = vim.fn.readfile(path)
      assert.truthy(#content >= 2)
      local found = false
      for _, line in ipairs(content) do
        if line:match("\x1b%[2m") or line:match("# hello") then
          found = true
        end
      end
      assert.True(found)
    end)

    it("appends write messages as-is", function()
      local path = logfile.start_run("python", "test", "bar.py")
      logfile.write("plain output\n")
      logfile.close_run()

      local content = vim.fn.readfile(path)
      local found = false
      for _, line in ipairs(content) do
        if line:match("plain output") then
          found = true
        end
      end
      assert.True(found)
    end)

    it("appends error messages with ANSI red", function()
      local path = logfile.start_run("python", "test", "baz.py")
      logfile.error("error!\n")
      logfile.close_run()

      local content = vim.fn.readfile(path)
      local found = false
      for _, line in ipairs(content) do
        if line:match("\x1b%[31m") or line:match("error!") then
          found = true
        end
      end
      assert.True(found)
    end)
  end)

  describe("list_logs", function()
    it("returns empty list when no logs exist", function()
      local logs = logfile.list_logs()
      assert.are.same({}, logs)
    end)

    it("lists created log files sorted by mtime desc", function()
      local p1 = logfile.start_run("python", "a", "one.py")
      logfile.close_run()
      local p2 = logfile.start_run("sql", "b", "two.py")
      logfile.close_run()

      local logs = logfile.list_logs()
      assert.equal(2, #logs)
      assert.True(logs[1].mtime >= logs[2].mtime)
    end)
  end)

  describe("log command", function()
    it("parse returns list mode with no args", function()
      local result = log_cmd.parse({})
      assert.truthy(result)
      assert.equal("list", result.mode)
      assert.is_nil(result.name)
    end)

    it("parse returns open mode with name arg", function()
      local result = log_cmd.parse({ "some_file.log" })
      assert.truthy(result)
      assert.equal("open", result.mode)
      assert.equal("some_file.log", result.name)
    end)

    it("help returns string", function()
      assert.truthy(log_cmd.help())
    end)
  end)
end)
