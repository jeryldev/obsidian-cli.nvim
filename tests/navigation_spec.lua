-- Tests for navigation commands: Outline, Links, Orphans, Deadends, FollowLink, Backlinks

local h = require("tests.helpers")

describe("navigation", function()
  after_each(h.restore)

  describe(":ObsidianOutline", function()
    it("parses outline JSON and shows picker with headings", function()
      h.setup_with_mock({
        ["outline"] = {
          stdout = '[{"level":2,"heading":"Introduction","line":"3"},{"level":3,"heading":"Background","line":"10"}]',
        },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "test content" })
      h.set_buf_name(buf, "/vault/test.md")
      vim.cmd("ObsidianOutline")
      local pick = h.last_picker()
      assert.is_not_nil(pick)
      assert.equals(2, #pick.items)
      assert.matches("Introduction", pick.items[1].text)
      assert.equals(3, pick.items[1].lnum)
      assert.matches("Background", pick.items[2].text)
      assert.equals(10, pick.items[2].lnum)
    end)

    it("handles empty outline", function()
      h.setup_with_mock({
        ["outline"] = { stdout = "No headings found." },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "no headings here" })
      h.set_buf_name(buf, "/vault/flat.md")
      vim.cmd("ObsidianOutline")
      assert.matches("no headings", h.last_notification())
    end)
  end)

  describe(":ObsidianLinks", function()
    it("shows outgoing links as picker", function()
      h.setup_with_mock({
        ["links"] = { stdout = "Welcome.md\nDaily.md\n" },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "content" })
      h.set_buf_name(buf, "/vault/note.md")
      vim.cmd("ObsidianLinks")
      local pick = h.last_picker()
      assert.is_not_nil(pick)
      assert.equals(2, #pick.items)
      assert.matches("Welcome.md", pick.items[1].display)
    end)

    it("handles no outgoing links", function()
      h.setup_with_mock({
        ["links"] = { stdout = "No links found." },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "island note" })
      h.set_buf_name(buf, "/vault/island.md")
      vim.cmd("ObsidianLinks")
      assert.matches("no outgoing links", h.last_notification())
    end)
  end)

  describe(":ObsidianOrphans", function()
    it("lists files with no incoming links", function()
      h.setup_with_mock({
        ["orphans"] = { stdout = "lonely.md\nforgotten.md\n" },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianOrphans")
      local pick = h.last_picker()
      assert.is_not_nil(pick)
      assert.equals(2, #pick.items)
      assert.matches("lonely.md", pick.items[1].display)
    end)

    it("handles no orphans", function()
      h.setup_with_mock({
        ["orphans"] = { stdout = "No orphans found." },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianOrphans")
      assert.matches("no orphan files", h.last_notification())
    end)
  end)

  describe(":ObsidianDeadends", function()
    it("lists files with no outgoing links", function()
      h.setup_with_mock({
        ["deadends"] = { stdout = "stub.md\nplaceholder.md\n" },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianDeadends")
      local pick = h.last_picker()
      assert.is_not_nil(pick)
      assert.equals(2, #pick.items)
    end)

    it("handles no deadends", function()
      h.setup_with_mock({
        ["deadends"] = { stdout = "No dead-ends found." },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianDeadends")
      assert.matches("no dead%-end files", h.last_notification())
    end)
  end)

  describe(":ObsidianFollowLink", function()
    it("jumps to existing file when link target exists", function()
      h.setup_with_mock({
        ["files"] = { stdout = "Welcome.md\nDaily.md\n" },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "See [[Welcome]] for info" })
      h.set_buf_name(buf, "/vault/source.md")
      vim.api.nvim_win_set_cursor(0, { 1, 6 }) -- cursor on "Welcome"
      vim.cmd("ObsidianFollowLink")
      local name = vim.api.nvim_buf_get_name(0)
      assert.matches("Welcome%.md$", name)
    end)

    it("errors when cursor is not on a wiki link", function()
      h.setup_with_mock({
        ["files"] = { stdout = "Welcome.md\n" },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "plain text no links" })
      h.set_buf_name(buf, "/vault/source.md")
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.cmd("ObsidianFollowLink")
      assert.matches("no %[%[wiki link%]%]", h.last_notification())
    end)

    it("strips alias when resolving", function()
      h.setup_with_mock({
        ["files"] = { stdout = "Welcome.md\n" },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "See [[Welcome|Home Page]] here" })
      h.set_buf_name(buf, "/vault/source.md")
      vim.api.nvim_win_set_cursor(0, { 1, 6 })
      vim.cmd("ObsidianFollowLink")
      local name = vim.api.nvim_buf_get_name(0)
      assert.matches("Welcome%.md$", name)
    end)

    it("strips heading ref when resolving", function()
      h.setup_with_mock({
        ["files"] = { stdout = "Welcome.md\n" },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "See [[Welcome#Getting Started]]" })
      h.set_buf_name(buf, "/vault/source.md")
      vim.api.nvim_win_set_cursor(0, { 1, 6 })
      vim.cmd("ObsidianFollowLink")
      local name = vim.api.nvim_buf_get_name(0)
      assert.matches("Welcome%.md$", name)
    end)

    it("matches by basename when file is in a subfolder", function()
      h.setup_with_mock({
        ["files"] = { stdout = "folder/deep/Welcome.md\n" },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "See [[Welcome]] somewhere" })
      h.set_buf_name(buf, "/vault/source.md")
      vim.api.nvim_win_set_cursor(0, { 1, 6 })
      vim.cmd("ObsidianFollowLink")
      local name = vim.api.nvim_buf_get_name(0)
      assert.matches("folder/deep/Welcome%.md$", name)
    end)
  end)

  describe(":ObsidianBacklinks", function()
    it("parses backlinks JSON", function()
      h.setup_with_mock({
        ["backlinks"] = {
          stdout = '[{"file":"source.md","line":"5","text":"See [[target]]"}]',
        },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "I am the target" })
      h.set_buf_name(buf, "/vault/target.md")
      vim.cmd("ObsidianBacklinks")
      local pick = h.last_picker()
      assert.is_not_nil(pick)
      assert.equals(1, #pick.items)
      assert.matches("source.md", pick.items[1].display)
    end)

    it("handles empty backlinks", function()
      h.setup_with_mock({
        ["backlinks"] = { stdout = "No backlinks found." },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "lonely" })
      h.set_buf_name(buf, "/vault/lonely.md")
      vim.cmd("ObsidianBacklinks")
      local pick = h.last_picker()
      assert.is_not_nil(pick)
      assert.equals(0, #pick.items)
    end)
  end)
end)
