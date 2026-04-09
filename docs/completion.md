# Wiki link completion

`obsidian-cli.nvim` ships a [`blink.cmp`](https://github.com/saghen/blink.cmp) source that provides vault-aware autocompletion for `[[wiki links]]`.

## What it does

When you type `[[` inside a vault markdown file, a completion popup appears showing every note in your vault. As you continue typing, the list narrows. Accepting a completion replaces your partial input with the full link, including the closing `]]` brackets.

The source is **vault-aware** — it queries `obsidian files` at runtime to get the actual file list, so it always reflects the current vault state (cached for 2 seconds to avoid hammering the CLI on every keystroke).

## Setup

LazyVim ships `blink.cmp` by default. To register the obsidian source, create `~/.config/nvim/lua/plugins/blink.lua`:

```lua
return {
  {
    "saghen/blink.cmp",
    optional = true,
    opts = {
      sources = {
        default = { "lsp", "path", "snippets", "buffer", "obsidian" },
        providers = {
          obsidian = {
            name = "Obsidian",
            module = "obsidian-cli.completion.blink",
            score_offset = 100,
          },
        },
      },
    },
  },
}
```

After restarting Neovim, type `[[` in any vault markdown file and the popup should show your vault notes.

## Suppressing other sources inside `[[...]]`

By default, blink.cmp shows results from all sources simultaneously — LSP, snippets, buffer text, GitHub Copilot, etc. Inside a `[[...]]` context, those sources produce noise (random buffer text matches, snippet triggers, malformed Copilot guesses).

The recommended config silences them inside wiki link context so the popup shows **only** vault notes:

```lua
local function in_wiki_context()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local before = line:sub(1, col)
  return before:match("%[%[[^%[%]]*$") ~= nil
end

local function not_in_wiki()
  return not in_wiki_context()
end

return {
  {
    "saghen/blink.cmp",
    optional = true,
    opts = {
      sources = {
        default = { "lsp", "path", "snippets", "buffer", "obsidian" },
        providers = {
          obsidian = {
            name = "Obsidian",
            module = "obsidian-cli.completion.blink",
            score_offset = 100,
          },
          lsp = { enabled = not_in_wiki },
          path = { enabled = not_in_wiki },
          snippets = { enabled = not_in_wiki },
          buffer = { enabled = not_in_wiki },
          copilot = { enabled = not_in_wiki },
        },
      },
    },
  },
}
```

The `enabled` callback runs per-keystroke. The moment your cursor leaves a `[[...` context, all the other sources come back to life.

## Auto-pairs interop

If you use auto-pairs (`mini.pairs`, `nvim-autopairs`, or blink's built-in pairs), typing `[[` automatically inserts `]]` and places your cursor between them. The completion source detects this and **consumes the existing `]]`** when accepting a completion, so you always get exactly `[[Note Name]]` regardless of whether auto-pairs added closing brackets or not.

This works for:
- `[[|]]` → `[[Note]]` (auto-pairs added `]]`)
- `[[|]` → `[[Note]]` (one bracket somehow)
- `[[|` → `[[Note]]` (no auto-pairs, end of line)

## Triggering manually

The source registers `[` as a trigger character. As soon as blink.cmp sees `[[` (the second bracket), it queries the source. There's no manual trigger keybinding — it's automatic.

If you want to force-trigger the popup:

```lua
vim.keymap.set("i", "<C-Space>", function()
  require("blink.cmp").show()
end)
```

## Display format

Completion items show the **vault-relative path without the `.md` extension**:

| File on disk | Completion label |
|---|---|
| `Welcome.md` | `Welcome` |
| `daily/2026-04-08.md` | `daily/2026-04-08` |
| `courses/MIB/notes.md` | `courses/MIB/notes` |

When accepted, the inserted text is the same as the label, wrapped in `[[...]]`. Obsidian's wiki link resolution accepts both basenames (`[[Welcome]]`) and paths (`[[daily/2026-04-08]]`); the source uses the full path to keep links unambiguous when you have notes with duplicate basenames.

## Cache behavior

- The vault file list is cached for 2 seconds after each query
- A new completion within the cache window reuses the cached list (no CLI call)
- After 2 seconds of idle, the next completion re-queries the CLI
- Newly created notes appear in completions within at most 2 seconds

If you create a note via `:ObsidianNew` and immediately try to link to it, it might not appear in the popup until the cache expires. You can force a refresh by waiting briefly or by triggering a CLI-bypassing operation that resets the cache.

## Limitations (v0.0.x)

- **No display-text alias support yet.** Typing `|` after a link to add display text (`[[Welcome|my starter note]]`) requires manually typing the alias portion. Planned for v0.1.0.
- **No heading/block reference completion.** `[[Welcome#Getting Started]]` requires typing the `#section` portion manually. Planned for v0.1.0.
- **No folder filtering.** All vault notes appear in completions. A `completion.folder = "inbox"` config option for scoping is planned for v0.1.0.
- **blink.cmp only.** Telescope-based pickers and nvim-cmp source planned for v0.1.0.

## Troubleshooting

### Popup doesn't appear when typing `[[`

1. Check the source is registered: `:lua print(vim.inspect(require("blink.cmp").get_sources and require("blink.cmp").get_sources()))` should include `"obsidian"`.
2. Check the buffer is recognized as a vault file: `:lua print(require("obsidian-cli.util").in_vault(vim.api.nvim_buf_get_name(0), require("obsidian-cli.cli").vault_path()))` should print `true`.
3. Verify the cache is populated: `:lua print(vim.inspect(require("obsidian-cli.cli").run({"files", "ext=md"})))` should print a list of markdown files.

### Popup shows other sources mixing in

You're missing the `enabled = not_in_wiki` callbacks on the other sources. Copy the full snippet from "Suppressing other sources inside `[[...]]`" above.

### Completion produces extra brackets

You probably have an old auto-pairs interop bug. Update to v0.0.3 or later — the textEdit range now consumes existing `]]` characters automatically.

### Completion is slow

The first completion in a session has a CLI cold-start (~30-50ms). Subsequent completions hit the cache. If you see persistent slowness, check `obsidian files | wc -l` — vaults over 5000 markdown files may need pre-filtering on the query string (planned for v0.1.0).
