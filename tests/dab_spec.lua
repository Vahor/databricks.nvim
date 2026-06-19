local dab = require("databricks.dab")

describe("dab", function()
  local tmpdir

  before_each(function()
    tmpdir = vim.fn.tempname() .. "_dab_test"
    vim.fn.mkdir(tmpdir, "p")
  end)

  after_each(function()
    vim.fn.delete(tmpdir, "rf")
  end)

  it("detects databricks.yml in directory", function()
    vim.fn.writefile({}, tmpdir .. "/databricks.yml")
    assert.True(dab.is_dab_root(tmpdir))
  end)

  it("returns false when no databricks.yml", function()
    assert.False(dab.is_dab_root(tmpdir))
  end)

  it("finds root walking upward", function()
    vim.fn.writefile({}, tmpdir .. "/databricks.yml")
    local subdir = tmpdir .. "/sub/deep"
    vim.fn.mkdir(subdir, "p")
    assert.equal(vim.fs.normalize(tmpdir), dab.find_root(subdir))
  end)

  it("returns nil when no root found", function()
    assert.is_nil(dab.find_root(tmpdir))
  end)

  it("is_dab_project returns true inside DAB", function()
    vim.fn.writefile({}, tmpdir .. "/databricks.yml")
    assert.True(dab.is_dab_project(tmpdir))
  end)
end)
