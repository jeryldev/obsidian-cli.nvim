-- Unit tests for lua/obsidian-cli/util.lua

local util = require("obsidian-cli.util")

describe("util.is_absolute", function()
  it("returns true for unix absolute paths", function()
    assert.is_true(util.is_absolute("/foo"))
    assert.is_true(util.is_absolute("/foo/bar/baz.md"))
    assert.is_true(util.is_absolute("/"))
  end)

  it("returns true for windows absolute paths", function()
    assert.is_true(util.is_absolute("C:\\foo"))
    assert.is_true(util.is_absolute("C:/foo"))
    assert.is_true(util.is_absolute("D:\\Users\\jeryl\\note.md"))
    assert.is_true(util.is_absolute("z:/lower/case.md"))
  end)

  it("returns false for relative paths", function()
    assert.is_false(util.is_absolute("foo"))
    assert.is_false(util.is_absolute("foo/bar.md"))
    assert.is_false(util.is_absolute("./note.md"))
    assert.is_false(util.is_absolute("../parent.md"))
  end)

  it("returns false for empty or nil", function()
    assert.is_false(util.is_absolute(""))
    assert.is_false(util.is_absolute(nil))
  end)
end)

describe("util.absolute", function()
  local vault = "/home/user/vault"

  it("joins a relative path to the vault", function()
    assert.equals("/home/user/vault/note.md", util.absolute("note.md", vault))
    assert.equals("/home/user/vault/folder/note.md", util.absolute("folder/note.md", vault))
  end)

  it("returns an already-absolute path unchanged", function()
    assert.equals("/elsewhere/abs.md", util.absolute("/elsewhere/abs.md", vault))
  end)

  it("handles trailing slashes on the vault", function()
    assert.equals("/home/user/vault/note.md", util.absolute("note.md", "/home/user/vault/"))
    assert.equals("/home/user/vault/note.md", util.absolute("note.md", "/home/user/vault///"))
  end)

  it("returns nil for empty relative path", function()
    assert.is_nil(util.absolute("", vault))
    assert.is_nil(util.absolute(nil, vault))
  end)

  it("returns the relative path when vault is missing", function()
    assert.equals("note.md", util.absolute("note.md", nil))
    assert.equals("note.md", util.absolute("note.md", ""))
  end)
end)

describe("util.relative_to_vault", function()
  local vault = "/home/user/vault"

  it("strips the vault prefix", function()
    assert.equals("note.md", util.relative_to_vault("/home/user/vault/note.md", vault))
    assert.equals("folder/note.md", util.relative_to_vault("/home/user/vault/folder/note.md", vault))
  end)

  it("returns the absolute path unchanged when outside the vault", function()
    assert.equals("/somewhere/else.md", util.relative_to_vault("/somewhere/else.md", vault))
  end)

  it("handles trailing slashes on the vault", function()
    assert.equals("note.md", util.relative_to_vault("/home/user/vault/note.md", "/home/user/vault/"))
  end)

  it("does not match partial prefixes", function()
    -- "/home/user/vault2/note.md" should NOT be stripped by vault "/home/user/vault"
    assert.equals(
      "/home/user/vault2/note.md",
      util.relative_to_vault("/home/user/vault2/note.md", vault)
    )
  end)

  it("passes through nil/empty", function()
    assert.is_nil(util.relative_to_vault(nil, vault))
    assert.equals("", util.relative_to_vault("", vault))
  end)
end)

describe("util.in_vault", function()
  local vault = "/home/user/vault"

  it("returns true when path is inside vault", function()
    assert.is_true(util.in_vault("/home/user/vault/note.md", vault))
    assert.is_true(util.in_vault("/home/user/vault/folder/deep/note.md", vault))
  end)

  it("returns false when path is outside vault", function()
    assert.is_false(util.in_vault("/home/user/other/note.md", vault))
    assert.is_false(util.in_vault("/elsewhere.md", vault))
  end)

  it("does not match partial prefixes", function()
    assert.is_false(util.in_vault("/home/user/vault2/note.md", vault))
  end)

  it("returns false for nil/empty inputs", function()
    assert.is_false(util.in_vault(nil, vault))
    assert.is_false(util.in_vault("", vault))
    assert.is_false(util.in_vault("/some/path.md", nil))
    assert.is_false(util.in_vault("/some/path.md", ""))
  end)
end)

describe("util.split_lines", function()
  it("splits on newlines and trims empty lines", function()
    local result = util.split_lines("foo\nbar\nbaz")
    assert.equals(3, #result)
    assert.equals("foo", result[1])
    assert.equals("bar", result[2])
    assert.equals("baz", result[3])
  end)

  it("trims leading and trailing whitespace from the input", function()
    local result = util.split_lines("  foo\nbar  ")
    assert.equals(2, #result)
    assert.equals("foo", result[1])
  end)

  it("returns empty table for empty input", function()
    assert.same({}, util.split_lines(""))
    assert.same({}, util.split_lines(nil))
  end)

  it("skips blank lines between content", function()
    local result = util.split_lines("foo\n\n\nbar")
    assert.equals(2, #result)
    assert.equals("foo", result[1])
    assert.equals("bar", result[2])
  end)
end)

describe("util.expand", function()
  it("expands ~ at the start of a path", function()
    local home = vim.fn.expand("$HOME")
    assert.equals(home .. "/foo", util.expand("~/foo"))
  end)

  it("leaves absolute paths unchanged", function()
    assert.equals("/absolute/path", util.expand("/absolute/path"))
  end)

  it("handles nil and empty", function()
    assert.is_nil(util.expand(nil))
    assert.equals("", util.expand(""))
  end)
end)
