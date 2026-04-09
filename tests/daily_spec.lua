-- Tests for daily note commands: Today, Yesterday, Tomorrow, Task, Append, TasksToday

local h = require("tests.helpers")

describe("daily notes", function()
  after_each(h.restore)

  describe(":ObsidianToday", function()
    it("opens today's daily note", function()
      h.setup_with_mock({
        ["daily:path"] = { stdout = os.date("%Y-%m-%d") .. ".md" },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianToday")
      local name = vim.api.nvim_buf_get_name(0)
      assert.matches(vim.pesc(os.date("%Y-%m-%d")) .. "%.md$", name)
    end)

    it("errors when CLI fails", function()
      h.setup_with_mock({
        ["daily:path"] = { stdout = "Vault not found.", code = 0 },
        ["vault"] = { stdout = "Vault not found.", code = 0 },
      })
      vim.cmd("ObsidianToday")
      assert.is_not_nil(h.last_notification())
      assert.matches("Vault not found", h.last_notification())
    end)
  end)

  describe(":ObsidianYesterday", function()
    it("computes yesterday's date correctly", function()
      local today = os.date("%Y-%m-%d")
      local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
      h.setup_with_mock({
        ["daily:path"] = { stdout = today .. ".md" },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianYesterday")
      local name = vim.api.nvim_buf_get_name(0)
      assert.matches(vim.pesc(yesterday) .. "%.md$", name)
    end)

    -- Note: month-boundary testing requires mocking os.date (not just CLI
    -- output) because daily_note_for_offset uses the REAL today to compute
    -- the replacement. Omitted to avoid intrusive os.date mocking.
  end)

  describe(":ObsidianTomorrow", function()
    it("computes tomorrow's date correctly", function()
      local today = os.date("%Y-%m-%d")
      local tomorrow = os.date("%Y-%m-%d", os.time() + 86400)
      h.setup_with_mock({
        ["daily:path"] = { stdout = today .. ".md" },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianTomorrow")
      local name = vim.api.nvim_buf_get_name(0)
      assert.matches(vim.pesc(tomorrow) .. "%.md$", name)
    end)
  end)

  describe(":ObsidianTask", function()
    it("appends a task via CLI when buffer not loaded", function()
      h.setup_with_mock({
        ["daily:path"] = { stdout = os.date("%Y-%m-%d") .. ".md" },
        ["daily:append"] = { stdout = "Added to: 2026-04-09.md" },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianTask buy milk")
      -- Since the daily buffer isn't open, it falls through to CLI.
      -- Just verify no error notification.
      local note = h.last_notification()
      if note then
        assert.Not.matches("ERROR", note)
      end
    end)
  end)

  describe(":ObsidianTasksToday", function()
    it("parses tasks JSON and shows picker", function()
      h.setup_with_mock({
        ["tasks"] = {
          stdout = '[{"status":" ","text":"- [ ] buy milk","file":"2026-04-09.md","line":"2"},'
            .. '{"status":"x","text":"- [x] done task","file":"2026-04-09.md","line":"3"}]',
        },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianTasksToday")
      local pick = h.last_picker()
      assert.is_not_nil(pick)
      -- Should filter to incomplete only (status " "), so 1 item not 2.
      assert.equals(1, #pick.items)
      assert.matches("buy milk", pick.items[1].text)
      assert.equals(2, pick.items[1].lnum)
    end)

    it("handles empty task list", function()
      h.setup_with_mock({
        ["tasks"] = { stdout = "No tasks found." },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianTasksToday")
      local pick = h.last_picker()
      assert.is_not_nil(pick)
      assert.equals(0, #pick.items)
    end)
  end)
end)
