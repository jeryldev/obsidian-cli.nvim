-- Tests for lua/obsidian-cli/cli.lua error detection and JSON parsing.
-- These tests mock vim.system to avoid invoking the real obsidian binary,
-- isolating the pure-Lua logic in cli.lua.

local cli = require("obsidian-cli.cli")

-- Capture and restore the real vim.system across tests.
local real_system = vim.system

local function mock_system(stdout, stderr, code)
  stdout = stdout or ""
  stderr = stderr or ""
  code = code or 0
  vim.system = function(_, _)
    return {
      wait = function()
        return {
          code = code,
          stdout = stdout,
          stderr = stderr,
        }
      end,
    }
  end
end

local function restore_system()
  vim.system = real_system
end

local function setup_cli()
  cli.setup({
    binary = "obsidian",
    vault = nil,
    vault_path = nil,
  })
end

describe("cli.run", function()
  before_each(function()
    setup_cli()
  end)
  after_each(restore_system)

  it("returns stdout on success", function()
    mock_system("hello world", "", 0)
    local out, err = cli.run({ "version" })
    assert.is_nil(err)
    assert.equals("hello world", out)
  end)

  it("returns error on non-zero exit", function()
    mock_system("", "something broke", 1)
    local out, err = cli.run({ "foo" })
    assert.is_nil(out)
    assert.equals("something broke", err)
  end)

  it("detects 'Vault not found.' on stdout with exit 0", function()
    mock_system("Vault not found.", "", 0)
    local out, err = cli.run({ "version" })
    assert.is_nil(out)
    assert.is_not_nil(err)
    assert.matches("Vault not found", err)
  end)

  it("detects 'The CLI is unable to find Obsidian' on stdout with exit 0", function()
    mock_system("The CLI is unable to find Obsidian. Please make sure Obsidian is running.", "", 0)
    local out, err = cli.run({ "version" })
    assert.is_nil(out)
    assert.is_not_nil(err)
    assert.matches("unable to find Obsidian", err)
  end)

  it("detects generic Error: prefix on stdout", function()
    mock_system("Error: something went wrong", "", 0)
    local out, err = cli.run({ "foo" })
    assert.is_nil(out)
    assert.matches("something went wrong", err)
  end)

  it("returns default error message for non-zero exit with empty output", function()
    mock_system("", "", 42)
    local out, err = cli.run({ "foo" })
    assert.is_nil(out)
    assert.matches("exited with code 42", err)
  end)
end)

describe("cli.run_json", function()
  before_each(function()
    setup_cli()
  end)
  after_each(restore_system)

  it("parses valid JSON", function()
    mock_system('[{"id":"foo"},{"id":"bar"}]', "", 0)
    local data, err = cli.run_json({ "something" })
    assert.is_nil(err)
    assert.is_table(data)
    assert.equals(2, #data)
    assert.equals("foo", data[1].id)
    assert.equals("bar", data[2].id)
  end)

  it("returns empty table for empty output", function()
    mock_system("", "", 0)
    local data, err = cli.run_json({ "something" })
    assert.is_nil(err)
    assert.same({}, data)
  end)

  it("treats 'No X found.' as empty result, not an error", function()
    mock_system("No tasks found.", "", 0)
    local data, err = cli.run_json({ "tasks" })
    assert.is_nil(err)
    assert.same({}, data)
  end)

  it("treats 'No backlinks found.' as empty result", function()
    mock_system("No backlinks found.", "", 0)
    local data, err = cli.run_json({ "backlinks" })
    assert.is_nil(err)
    assert.same({}, data)
  end)

  it("returns error on invalid JSON", function()
    mock_system("this is not json", "", 0)
    local data, err = cli.run_json({ "something" })
    assert.is_nil(data)
    assert.is_not_nil(err)
    assert.matches("failed to parse JSON", err)
  end)

  it("propagates upstream errors", function()
    mock_system("", "boom", 1)
    local data, err = cli.run_json({ "something" })
    assert.is_nil(data)
    assert.equals("boom", err)
  end)

  it("propagates stdout-as-error sentinels", function()
    mock_system("Vault not found.", "", 0)
    local data, err = cli.run_json({ "something" })
    assert.is_nil(data)
    assert.matches("Vault not found", err)
  end)
end)

describe("cli.vault_path", function()
  before_each(function()
    cli.reset_vault_cache()
    cli.setup({
      binary = "obsidian",
      vault = nil,
      vault_path = nil,
    })
  end)
  after_each(restore_system)

  it("returns the configured vault_path if set (no CLI call)", function()
    cli.setup({ binary = "obsidian", vault_path = "/explicit/path" })
    -- No mock needed — should not call vim.system
    local p = cli.vault_path()
    assert.equals("/explicit/path", p)
  end)

  it("auto-detects via CLI when vault_path is nil", function()
    mock_system("/auto/detected/path\n", "", 0)
    local p = cli.vault_path()
    assert.equals("/auto/detected/path", p)
  end)

  it("caches the result across calls", function()
    local call_count = 0
    vim.system = function(_, _)
      call_count = call_count + 1
      return {
        wait = function()
          return { code = 0, stdout = "/cached/path", stderr = "" }
        end,
      }
    end
    cli.vault_path()
    cli.vault_path()
    cli.vault_path()
    assert.equals(1, call_count)
  end)

  it("reset_vault_cache forces re-detection", function()
    local call_count = 0
    vim.system = function(_, _)
      call_count = call_count + 1
      return {
        wait = function()
          return { code = 0, stdout = "/cached/path", stderr = "" }
        end,
      }
    end
    cli.vault_path()
    cli.reset_vault_cache()
    cli.vault_path()
    assert.equals(2, call_count)
  end)

  it("returns error when CLI reports Vault not found", function()
    mock_system("Vault not found.", "", 0)
    local p, err = cli.vault_path()
    assert.is_nil(p)
    assert.is_not_nil(err)
  end)
end)
