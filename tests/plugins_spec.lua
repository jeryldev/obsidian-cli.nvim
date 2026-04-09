-- Tests for plugin management and escape hatch commands

local h = require("tests.helpers")

describe("escape hatch", function()
  after_each(h.restore)

  describe(":ObsidianCommand", function()
    it("runs a command by ID", function()
      h.setup_with_mock({
        ["command"] = { stdout = "" },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianCommand app:reload")
      assert.matches("Ran: app:reload", h.last_notification())
    end)

    it("reports CLI errors", function()
      h.setup_with_mock({
        ["command"] = { stdout = "", stderr = "Unknown command: nope", code = 1 },
      })
      vim.cmd("ObsidianCommand nope:nope")
      assert.matches("Unknown command", h.last_notification())
    end)
  end)

  describe(":ObsidianCommandList", function()
    it("builds items from commands output", function()
      h.setup_with_mock({
        ["commands"] = { stdout = "app:reload\napp:quit\ndaily-notes\n" },
        ["vault"] = { stdout = "/vault" },
        -- Auto-select first item triggers command execution:
        ["command"] = { stdout = "" },
      })
      vim.cmd("ObsidianCommandList")
      local pick = h.last_picker()
      assert.is_not_nil(pick)
      assert.is_true(pick.select)
      assert.equals(3, #pick.items)
      assert.equals("app:reload", pick.items[1].command_id)
    end)

    it("filters by prefix", function()
      h.setup_with_mock({
        ["commands"] = { stdout = "daily-notes\n" },
        ["vault"] = { stdout = "/vault" },
        ["command"] = { stdout = "" },
      })
      vim.cmd("ObsidianCommandList daily")
      local pick = h.last_picker()
      assert.is_not_nil(pick)
      assert.equals(1, #pick.items)
    end)
  end)
end)

describe("plugin management", function()
  after_each(h.restore)

  describe(":ObsidianPluginInstall", function()
    it("installs and auto-enables", function()
      h.setup_with_mock({
        ["plugin:install"] = { stdout = "" },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianPluginInstall test-plugin")
      assert.matches("Installed and enabled: test%-plugin", h.last_notification())
    end)

    it("reports CLI errors", function()
      h.setup_with_mock({
        ["plugin:install"] = { stdout = "", stderr = "Plugin not found", code = 1 },
      })
      vim.cmd("ObsidianPluginInstall nonexistent")
      assert.matches("Plugin not found", h.last_notification())
    end)
  end)

  describe(":ObsidianPluginEnable", function()
    it("enables a plugin", function()
      h.setup_with_mock({
        ["plugin:enable"] = { stdout = "" },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianPluginEnable test-plugin")
      assert.matches("Enabled: test%-plugin", h.last_notification())
    end)
  end)

  describe(":ObsidianPluginDisable", function()
    it("disables with confirmation", function()
      h.setup_with_mock({
        ["plugin:disable"] = { stdout = "" },
        ["vault"] = { stdout = "/vault" },
      })
      vim.fn.confirm = function()
        return 1
      end
      vim.cmd("ObsidianPluginDisable test-plugin")
      assert.matches("Disabled: test%-plugin", h.last_notification())
    end)

    it("cancels when user declines", function()
      h.setup_with_mock({
        ["vault"] = { stdout = "/vault" },
      })
      vim.fn.confirm = function()
        return 2
      end
      vim.cmd("ObsidianPluginDisable test-plugin")
      assert.matches("Cancelled", h.last_notification())
    end)
  end)

  describe(":ObsidianPluginReload", function()
    it("reloads a plugin", function()
      h.setup_with_mock({
        ["plugin:reload"] = { stdout = "" },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianPluginReload test-plugin")
      assert.matches("Reloaded: test%-plugin", h.last_notification())
    end)
  end)

  describe(":ObsidianPluginInfo", function()
    it("shows plugin metadata", function()
      h.setup_with_mock({
        ["plugin"] = { stdout = "id: test-plugin\nversion: 1.0.0\nenabled: true" },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianPluginInfo test-plugin")
      -- Should show the metadata via vim.notify.
      assert.matches("test%-plugin", h.last_notification())
    end)
  end)

  describe(":ObsidianRestrictedMode", function()
    it("queries current state without args", function()
      h.setup_with_mock({
        ["plugins:restrict"] = { stdout = "off" },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianRestrictedMode")
      assert.matches("Restricted mode: off", h.last_notification())
    end)

    it("turns on restricted mode", function()
      h.setup_with_mock({
        ["plugins:restrict"] = { stdout = "" },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianRestrictedMode on")
      assert.matches("Restricted mode ON", h.last_notification())
    end)

    it("turns off restricted mode", function()
      h.setup_with_mock({
        ["plugins:restrict"] = { stdout = "" },
        ["vault"] = { stdout = "/vault" },
      })
      vim.cmd("ObsidianRestrictedMode off")
      assert.matches("Restricted mode OFF", h.last_notification())
    end)
  end)
end)
