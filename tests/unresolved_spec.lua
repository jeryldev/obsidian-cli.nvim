-- Tests for :ObsidianUnresolved and :ObsidianResolveLink

local h = require("tests.helpers")

describe("unresolved links", function()
  after_each(h.restore)
  before_each(function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) ~= "" then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end)

  describe(":ObsidianUnresolved", function()
    it("parses JSON with string sources", function()
      h.setup_with_mock({
        ["unresolved"] = {
          stdout = '[{"link":"create a link","count":"1","sources":"Welcome.md"}]',
        },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianUnresolved")
      local pick = h.last_picker()
      assert.is_not_nil(pick)
      assert.equals(1, #pick.items)
      assert.matches("create a link", pick.items[1].text)
      assert.matches("/vault/Welcome.md", pick.items[1].path)
      assert.is_not_nil(pick.items[1].search)
    end)

    it("handles comma-separated sources as multiple items", function()
      h.setup_with_mock({
        ["unresolved"] = {
          stdout = '[{"link":"missing note","count":"2","sources":"a.md, b.md"}]',
        },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianUnresolved")
      local pick = h.last_picker()
      assert.is_not_nil(pick)
      -- Two sources → two picker items for the same link.
      assert.equals(2, #pick.items)
      assert.matches("a.md", pick.items[1].path)
      assert.matches("b.md", pick.items[2].path)
    end)

    it("handles entries without sources", function()
      h.setup_with_mock({
        ["unresolved"] = {
          stdout = '[{"link":"orphan link"}]',
        },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianUnresolved")
      local pick = h.last_picker()
      assert.is_not_nil(pick)
      assert.equals(1, #pick.items)
      assert.matches("orphan link", pick.items[1].text)
    end)

    it("handles empty result", function()
      h.setup_with_mock({
        ["unresolved"] = { stdout = "No unresolved links found." },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianUnresolved")
      local pick = h.last_picker()
      assert.is_not_nil(pick)
      assert.equals(0, #pick.items)
    end)

    it("handles string entries in the array", function()
      h.setup_with_mock({
        ["unresolved"] = {
          stdout = '["missing.md","another.md"]',
        },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianUnresolved")
      local pick = h.last_picker()
      assert.is_not_nil(pick)
      assert.equals(2, #pick.items)
    end)
  end)

  describe(":ObsidianResolveLink", function()
    it("creates a note from [[link]] under cursor", function()
      h.setup_with_mock({
        ["create"] = { stdout = "" },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "See [[Future Idea]] here" })
      h.set_buf_name(buf, "/vault/source.md")
      vim.api.nvim_win_set_cursor(0, { 1, 6 }) -- inside [[Future Idea]]
      vim.cmd("ObsidianResolveLink")
      assert.matches("Future Idea", h.last_notification())
    end)

    it("strips alias from link", function()
      h.setup_with_mock({
        ["create"] = { stdout = "" },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "[[Real Name|Display Name]]" })
      h.set_buf_name(buf, "/vault/source.md")
      vim.api.nvim_win_set_cursor(0, { 1, 3 })
      vim.cmd("ObsidianResolveLink")
      assert.matches("Real Name", h.last_notification())
    end)

    it("strips heading ref from link", function()
      h.setup_with_mock({
        ["create"] = { stdout = "" },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "[[Note#Section]]" })
      h.set_buf_name(buf, "/vault/source.md")
      vim.api.nvim_win_set_cursor(0, { 1, 3 })
      vim.cmd("ObsidianResolveLink")
      assert.matches("Note", h.last_notification())
    end)

    it("strips block ref from link", function()
      h.setup_with_mock({
        ["create"] = { stdout = "" },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "[[Note^block-id]]" })
      h.set_buf_name(buf, "/vault/source.md")
      vim.api.nvim_win_set_cursor(0, { 1, 3 })
      vim.cmd("ObsidianResolveLink")
      assert.matches("Note", h.last_notification())
    end)

    it("errors when cursor is not on a wiki link", function()
      h.setup_with_mock({
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "no links here" })
      h.set_buf_name(buf, "/vault/source.md")
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.cmd("ObsidianResolveLink")
      assert.matches("no %[%[wiki link%]%]", h.last_notification())
    end)

    it("handles multiple links on the same line — picks the one under cursor", function()
      h.setup_with_mock({
        ["create"] = { stdout = "" },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "See [[First]] and [[Second]] here" })
      h.set_buf_name(buf, "/vault/source.md")
      -- Cursor on "Second" (column ~24)
      vim.api.nvim_win_set_cursor(0, { 1, 24 })
      vim.cmd("ObsidianResolveLink")
      assert.matches("Second", h.last_notification())
    end)
  end)
end)
