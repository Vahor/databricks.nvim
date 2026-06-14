--- Tests for databricks.dab — DAB project detection.
local dab = require("databricks.dab")
local config = require("databricks.config")

describe("databricks.dab", function()
  local tmpdir

  before_each(function()
    tmpdir = vim.fn.tempname() .. "_dab_test"
    vim.fn.mkdir(tmpdir, "p")
    config.setup({ dab = { file = "databricks.yml" } })
  end)

  after_each(function()
    vim.fn.delete(tmpdir, "rf")
  end)

  describe("is_dab_root", function()
    it("returns true when dab file exists", function()
      vim.fn.writefile({}, tmpdir .. "/databricks.yml")
      assert.True(dab.is_dab_root(tmpdir))
    end)

    it("returns false when dab file does not exist", function()
      assert.False(dab.is_dab_root(tmpdir))
    end)

    it("respects custom dab.file config", function()
      config.setup({ dab = { file = "custom.yml" } })
      vim.fn.writefile({}, tmpdir .. "/custom.yml")
      assert.True(dab.is_dab_root(tmpdir))

      -- Remove custom.yml, add databricks.yml → should NOT detect (wrong marker name)
      vim.fn.delete(tmpdir .. "/custom.yml")
      vim.fn.writefile({}, tmpdir .. "/databricks.yml")
      assert.False(dab.is_dab_root(tmpdir))
    end)
  end)

  describe("find_root", function()
    it("returns directory containing dab file", function()
      vim.fn.writefile({}, tmpdir .. "/databricks.yml")
      local subdir = tmpdir .. "/sub/deep"
      vim.fn.mkdir(subdir, "p")
      assert.equal(vim.fs.normalize(tmpdir), dab.find_root(subdir))
    end)

    it("returns nil when no dab file found upward", function()
      local subdir = tmpdir .. "/sub"
      vim.fn.mkdir(subdir, "p")
      assert.is_nil(dab.find_root(subdir))
    end)

    it("defaults to cwd when no path given", function()
      vim.fn.writefile({}, tmpdir .. "/databricks.yml")
      local old_cwd = vim.fn.getcwd()
      vim.fn.chdir(tmpdir)
      local result = vim.fn.resolve(dab.find_root())
      local expected = vim.fn.resolve(tmpdir)
      assert.equal(expected, result)
      vim.fn.chdir(old_cwd)
    end)
  end)

  describe("is_dab_project", function()
    it("returns true inside a DAB project", function()
      vim.fn.writefile({}, tmpdir .. "/databricks.yml")
      assert.True(dab.is_dab_project(tmpdir))
    end)

    it("returns false outside a DAB project", function()
      assert.False(dab.is_dab_project(tmpdir))
    end)
  end)
end)
