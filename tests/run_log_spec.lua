local logfile = require("databricks._commands.run.log")
local log_cmd = require("databricks._commands.log.run")
local config = require("databricks.config")
local dab = require("databricks.dab")

local TEST_DIR = vim.fn.stdpath("data") .. "/databricks-test"

local function log_dir()
  local root = dab.find_root()
  local subdir = root and vim.fn.fnamemodify(root, ":t") or vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  return TEST_DIR .. "/" .. subdir
end

describe("run log", function()
  before_each(function()
    vim.fn.system({ "rm", "-rf", TEST_DIR })
    config.setup({ log = { dir = TEST_DIR } })
  end)

  after_each(function()
    vim.fn.system({ "rm", "-rf", TEST_DIR })
  end)

  describe("start_run", function()
    it("creates a log file with header", function()
      local run_id = logfile.start_run("my-profile", "test.py")
      assert.truthy(run_id)
      local path = logfile.get_path(run_id)
      assert.truthy(path)
      assert.truthy(path:match("test%.py%.log$"))
      assert.truthy(vim.startswith(path, log_dir()))

      local f = io.open(path, "r")
      assert.truthy(f)
      local first_line = f:read("*l")
      f:close()

      assert.truthy(first_line:match("my%-profile"))
      logfile.close_run(run_id)
    end)

    it("uses unknown for nil source", function()
      local run_id = logfile.start_run("p", nil)
      assert.truthy(run_id)
      local path = logfile.get_path(run_id)
      assert.truthy(path)
      assert.truthy(path:match("unknown%.log$"))
      logfile.close_run(run_id)
    end)

    it("uses source-based name when log_name is boolean true (same as default)", function()
      local run_id = logfile.start_run("p", "mymod.py", true)
      assert.truthy(run_id)
      local path = logfile.get_path(run_id)
      assert.truthy(path)
      assert.truthy(path:match("mymod%.py%.log$"))
      logfile.close_run(run_id)
    end)

    it("uses custom name when log_name is a string", function()
      local run_id = logfile.start_run("p", "ignored.py", "my_debug")
      assert.truthy(run_id)
      local path = logfile.get_path(run_id)
      assert.truthy(path)
      assert.truthy(path:match("my_debug%.log$"))
      logfile.close_run(run_id)
    end)
  end)

  describe("log/write/error", function()
    it("appends log messages with ANSI dim", function()
      local run_id = logfile.start_run("python", "test", "foo.py")
      logfile.log("hello\n", run_id)
      local path = logfile.get_path(run_id)
      logfile.close_run(run_id)

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
      local run_id = logfile.start_run("python", "test", "bar.py")
      logfile.write("plain output\n", run_id)
      local path = logfile.get_path(run_id)
      logfile.close_run(run_id)

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
      local run_id = logfile.start_run("python", "test", "baz.py")
      logfile.error("error!\n", run_id)
      local path = logfile.get_path(run_id)
      logfile.close_run(run_id)

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
      local r1 = logfile.start_run("python", "a", "one.py")
      logfile.close_run(r1)
      local r2 = logfile.start_run("sql", "b", "two.py")
      logfile.close_run(r2)

      local logs = logfile.list_logs()
      assert.equal(2, #logs)
      assert.True(logs[1].mtime >= logs[2].mtime)
    end)
  end)

  describe("log command", function()
    it("help returns string", function()
      assert.truthy(log_cmd.help())
    end)
  end)
end)
