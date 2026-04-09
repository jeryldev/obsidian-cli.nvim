# Testing

`obsidian-cli.nvim` ships a test suite using [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)'s `busted`-style test harness. The suite runs in Neovim headless mode with no real Obsidian binary required — all CLI interactions are mocked.

## What's covered

| Spec file | Target module | Tests |
|---|---|---|
| `tests/util_spec.lua` | `lua/obsidian-cli/util.lua` | Path helpers — `is_absolute`, `absolute`, `relative_to_vault`, `in_vault`, `split_lines`, `expand` |
| `tests/config_spec.lua` | `lua/obsidian-cli/config.lua` | Default values, deep-merge behavior, user overrides |
| `tests/cli_spec.lua` | `lua/obsidian-cli/cli.lua` | Error detection (`Vault not found.` on stdout, `No X found.` empty results), JSON parsing, vault path caching |
| `tests/setup_spec.lua` | `lua/obsidian-cli/init.lua` | `setup()` end-to-end — command registration, keymap registration, config merging |

Total: **60+ tests** across 4 spec files as of v0.0.4.

## Running tests

### All tests
```sh
make test
```

Or directly:
```sh
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests {minimal_init = 'tests/minimal_init.lua'}"
```

### Single file
```sh
make test-file FILE=tests/util_spec.lua
```

Or:
```sh
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/util_spec.lua"
```

### Lint + test in one pass
```sh
make check
```

Runs `stylua --check`, `selene`, and the test suite. Use this before committing.

## Mocking conventions

Tests that exercise CLI interactions (e.g., `cli_spec.lua`) replace `vim.system` with a stub that returns canned output:

```lua
local real_system = vim.system

local function mock_system(stdout, stderr, code)
  vim.system = function(_, _)
    return {
      wait = function()
        return { code = code or 0, stdout = stdout or "", stderr = stderr or "" }
      end,
    }
  end
end

local function restore_system()
  vim.system = real_system
end
```

This isolates the pure-Lua logic from the actual `obsidian` binary, so tests run in CI without needing Obsidian installed.

**Don't shell out to the real CLI in tests.** The binary isn't available in CI and would couple test stability to a specific Obsidian version. If you need to test a new CLI quirk, add a mock that reproduces the behavior and document the quirk in `docs/architecture.md`.

## Writing new tests

Place new spec files in `tests/` with the `_spec.lua` suffix. Plenary's busted harness auto-discovers them.

Basic structure:

```lua
-- tests/my_module_spec.lua
local my_module = require("obsidian-cli.my_module")

describe("my_module.my_function", function()
  it("does the thing", function()
    local result = my_module.my_function("input")
    assert.equals("expected", result)
  end)

  it("handles edge cases", function()
    assert.is_nil(my_module.my_function(nil))
    assert.is_nil(my_module.my_function(""))
  end)
end)
```

Common assertions (from plenary/luassert):

```lua
assert.equals(expected, actual)
assert.is_true(value)
assert.is_false(value)
assert.is_nil(value)
assert.is_not_nil(value)
assert.is_table(value)
assert.is_string(value)
assert.same({a=1, b=2}, result)         -- deep equality
assert.matches("pattern", string)       -- Lua pattern match
```

Use `before_each`/`after_each` for per-test setup/teardown (e.g., restoring mocks).

## What NOT to test

1. **The Obsidian CLI itself** — we assume it works as documented. Tests for CLI behavior belong upstream.
2. **Neovim APIs** — we trust `vim.fn.expand`, `vim.api.nvim_*`, etc. Don't test that `vim.split` splits correctly.
3. **Plugin ecosystem integrations** that require external state (Templater, Dataview) — those can only be tested manually against a live vault.
4. **Live CLI invocations** — flaky, environment-dependent, doesn't belong in unit tests.

## CI

Tests run in GitHub Actions via `.github/workflows/ci.yml` alongside stylua and selene. Any PR that fails tests won't merge.

The CI installs plenary.nvim fresh on each run (no caching needed — it's small). Neovim is installed via `rhysd/action-setup-vim`.
