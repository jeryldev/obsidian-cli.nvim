-- Advanced daily note tests: in-buffer append, cursor jump, append vs task

local h = require("tests.helpers")

describe("daily in-buffer operations", function()
  after_each(h.restore)

  -- Wipe all buffers between tests to prevent E95 name collisions.
  before_each(function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) ~= "" then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end)

  describe("in-buffer task append", function()
    it("appends to buffer directly when today's note is open", function()
      h.setup_with_mock({
        ["daily:path"] = { stdout = "today.md" },
        ["vault"] = { stdout = "/vault" },
      })
      -- Simulate today's note being open in the current buffer.
      local buf = h.create_buffer({ "existing line 1", "existing line 2" })
      pcall(vim.api.nvim_buf_set_name, buf, "/vault/today.md")
      vim.cmd("ObsidianTask buy milk")
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.equals(3, #lines)
      assert.equals("existing line 1", lines[1])
      assert.equals("existing line 2", lines[2])
      assert.equals("- [ ] buy milk", lines[3])
    end)

    it("appends plain text without checkbox prefix via ObsidianAppend", function()
      h.setup_with_mock({
        ["daily:path"] = { stdout = "today.md" },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "line 1" })
      pcall(vim.api.nvim_buf_set_name, buf, "/vault/today.md")
      vim.cmd("ObsidianAppend Meeting notes: discussed Q1 goals")
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.equals(2, #lines)
      assert.equals("Meeting notes: discussed Q1 goals", lines[2])
    end)

    it("ObsidianTodo is identical to ObsidianTask", function()
      h.setup_with_mock({
        ["daily:path"] = { stdout = "today.md" },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "line 1" })
      pcall(vim.api.nvim_buf_set_name, buf, "/vault/today.md")
      vim.cmd("ObsidianTodo write docs")
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.equals("- [ ] write docs", lines[2])
    end)

    it("moves cursor to new line when today is current buffer", function()
      h.setup_with_mock({
        ["daily:path"] = { stdout = "today.md" },
        ["vault"] = { stdout = "/vault" },
      })
      local buf = h.create_buffer({ "line 1", "line 2" })
      pcall(vim.api.nvim_buf_set_name, buf, "/vault/today.md")
      vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- start at line 1
      vim.cmd("ObsidianTask test cursor jump")
      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(3, cursor[1]) -- should be on the new line (line 3)
    end)

    it("does NOT move cursor when today is a background buffer", function()
      h.setup_with_mock({
        ["daily:path"] = { stdout = "today.md" },
        ["daily:append"] = { stdout = "Added" },
        ["vault"] = { stdout = "/vault" },
      })
      -- Create today's buffer but switch away from it.
      local today_buf = h.create_buffer({ "today content" })
      pcall(vim.api.nvim_buf_set_name, today_buf, "/vault/today.md")
      local other_buf = h.create_buffer({ "other content" })
      vim.api.nvim_set_current_buf(other_buf)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.cmd("ObsidianTask background task")
      -- Cursor should still be at line 1 of the other buffer.
      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.equals(1, cursor[1])
      -- But the task should be appended to today's buffer.
      local lines = vim.api.nvim_buf_get_lines(today_buf, 0, -1, false)
      assert.equals("- [ ] background task", lines[2])
    end)
  end)
end)
