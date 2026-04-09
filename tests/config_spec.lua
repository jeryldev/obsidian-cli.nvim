-- Unit tests for lua/obsidian-cli/config.lua

local config = require("obsidian-cli.config")

describe("config.defaults", function()
  it("has all required default keys", function()
    assert.is_string(config.defaults.binary)
    assert.equals("obsidian", config.defaults.binary)
    assert.is_nil(config.defaults.vault)
    assert.is_nil(config.defaults.vault_path)
    assert.is_nil(config.defaults.picker)
    assert.is_true(config.defaults.keymaps)
    assert.equals(20, config.defaults.recent_limit)
    assert.is_true(config.defaults.disable_diagnostics_in_vault)
  end)

  it("has sensible buffer_options defaults", function()
    local bo = config.defaults.buffer_options
    assert.is_true(bo.wrap)
    assert.is_true(bo.linebreak)
    assert.is_true(bo.breakindent)
    assert.equals("80", bo.colorcolumn)
    assert.is_false(bo.spell) -- spell should default OFF in v0.0.3+
    assert.equals(2, bo.conceallevel)
  end)
end)

describe("config.merge", function()
  it("returns defaults when no opts given", function()
    local merged = config.merge(nil)
    assert.equals("obsidian", merged.binary)
    assert.equals(20, merged.recent_limit)
  end)

  it("returns defaults when opts is empty table", function()
    local merged = config.merge({})
    assert.equals("obsidian", merged.binary)
    assert.equals(20, merged.recent_limit)
  end)

  it("overrides scalar defaults with user opts", function()
    local merged = config.merge({ recent_limit = 50, binary = "/opt/obsidian" })
    assert.equals(50, merged.recent_limit)
    assert.equals("/opt/obsidian", merged.binary)
    -- Unspecified keys retain defaults
    assert.is_true(merged.keymaps)
  end)

  it("deep-merges buffer_options", function()
    local merged = config.merge({
      buffer_options = { spell = true, colorcolumn = "100" },
    })
    assert.is_true(merged.buffer_options.spell)
    assert.equals("100", merged.buffer_options.colorcolumn)
    -- Other buffer options retained
    assert.is_true(merged.buffer_options.wrap)
    assert.is_true(merged.buffer_options.linebreak)
  end)

  it("does not mutate the defaults table", function()
    local before = config.defaults.binary
    config.merge({ binary = "mutated" })
    assert.equals(before, config.defaults.binary)
  end)

  it("accepts buffer_options = false to disable", function()
    local merged = config.merge({ buffer_options = false })
    assert.is_false(merged.buffer_options)
  end)

  it("accepts disable_diagnostics_in_vault = false", function()
    local merged = config.merge({ disable_diagnostics_in_vault = false })
    assert.is_false(merged.disable_diagnostics_in_vault)
  end)
end)
