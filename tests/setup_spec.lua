-- Integration-level smoke tests: load the plugin via setup() and verify
-- all user commands are registered. Validates that init.lua's wiring
-- reaches commands.lua and picker setup without errors.

describe("obsidian-cli setup()", function()
  before_each(function()
    -- Force a fresh module state between tests.
    package.loaded["obsidian-cli"] = nil
    package.loaded["obsidian-cli.config"] = nil
    package.loaded["obsidian-cli.cli"] = nil
    package.loaded["obsidian-cli.commands"] = nil
    package.loaded["obsidian-cli.pickers"] = nil
    package.loaded["obsidian-cli.pickers.snacks"] = nil
    package.loaded["obsidian-cli.pickers.quickfix"] = nil
    package.loaded["obsidian-cli.util"] = nil
  end)

  it("loads without error on empty config", function()
    local ok, plugin = pcall(require, "obsidian-cli")
    assert.is_true(ok)
    plugin.setup({})
    assert.is_not_nil(plugin.config)
    assert.equals("obsidian", plugin.config.binary)
  end)

  it("merges user opts with defaults", function()
    local plugin = require("obsidian-cli")
    plugin.setup({ recent_limit = 100, keymaps = false })
    assert.equals(100, plugin.config.recent_limit)
    assert.is_false(plugin.config.keymaps)
    assert.equals("obsidian", plugin.config.binary)
  end)

  it("registers all v0.0.3 daily-driver commands", function()
    require("obsidian-cli").setup({})
    local expected = {
      "ObsidianToday",
      "ObsidianTask",
      "ObsidianTodo",
      "ObsidianAppend",
      "ObsidianTasksToday",
      "ObsidianTaskToggle",
      "ObsidianNew",
      "ObsidianNewFrom",
      "ObsidianFind",
      "ObsidianRecent",
      "ObsidianSearch",
      "ObsidianBacklinks",
      "ObsidianUnresolved",
      "ObsidianResolveLink",
      "ObsidianStart",
    }
    for _, name in ipairs(expected) do
      assert.equals(2, vim.fn.exists(":" .. name), "command not registered: " .. name)
    end
  end)

  it("registers v0.0.4 generic command runner", function()
    require("obsidian-cli").setup({})
    assert.equals(2, vim.fn.exists(":ObsidianCommand"))
    assert.equals(2, vim.fn.exists(":ObsidianCommandList"))
  end)

  it("registers v0.0.4 plugin management commands", function()
    require("obsidian-cli").setup({})
    local expected = {
      "ObsidianPluginList",
      "ObsidianPluginInstall",
      "ObsidianPluginUninstall",
      "ObsidianPluginEnable",
      "ObsidianPluginDisable",
      "ObsidianPluginReload",
      "ObsidianPluginInfo",
      "ObsidianRestrictedMode",
    }
    for _, name in ipairs(expected) do
      assert.equals(2, vim.fn.exists(":" .. name), "command not registered: " .. name)
    end
  end)

  it("registers v0.0.4 Bases commands", function()
    require("obsidian-cli").setup({})
    local expected = {
      "ObsidianBases",
      "ObsidianBaseViews",
      "ObsidianBaseQuery",
      "ObsidianBaseCreate",
    }
    for _, name in ipairs(expected) do
      assert.equals(2, vim.fn.exists(":" .. name), "command not registered: " .. name)
    end
  end)

  it("registers v0.0.5 navigation, CRUD, tags, and template commands", function()
    require("obsidian-cli").setup({})
    local expected = {
      "ObsidianYesterday",
      "ObsidianTomorrow",
      "ObsidianOutline",
      "ObsidianLinks",
      "ObsidianOrphans",
      "ObsidianDeadends",
      "ObsidianTags",
      "ObsidianTag",
      "ObsidianRename",
      "ObsidianMove",
      "ObsidianDelete",
      "ObsidianOpenInApp",
      "ObsidianTemplates",
      "ObsidianTemplateInsert",
      "ObsidianFollowLink",
    }
    for _, name in ipairs(expected) do
      assert.equals(2, vim.fn.exists(":" .. name), "command not registered: " .. name)
    end
  end)

  it("registers global keymaps when keymaps = true", function()
    require("obsidian-cli").setup({ keymaps = true })
    local ot = vim.fn.maparg("<leader>ot", "n")
    assert.is_not_equal("", ot)
  end)

  it("does NOT register global keymaps when keymaps = false", function()
    -- Clear any existing mapping first
    pcall(vim.keymap.del, "n", "<leader>ot")
    require("obsidian-cli").setup({ keymaps = false })
    local ot = vim.fn.maparg("<leader>ot", "n")
    assert.equals("", ot)
  end)
end)
