# Architecture

How `obsidian-cli.nvim` is structured and why.

## The big picture

```
┌─────────────────────────────┐
│  Neovim (you typing)        │
│  ┌──────────────────────┐   │
│  │ obsidian-cli.nvim    │   │
│  │  ├─ commands.lua     │   │
│  │  ├─ cli.lua          │   │
│  │  ├─ pickers/         │   │
│  │  ├─ completion/blink │   │
│  │  └─ util.lua         │   │
│  └──────────────────────┘   │
└─────────────┬───────────────┘
              │ vim.system({"obsidian", ...})
              ▼
┌─────────────────────────────┐
│  obsidian CLI binary        │
│  /usr/local/bin/obsidian    │
│  (symlink into .app bundle) │
└─────────────┬───────────────┘
              │ IPC
              ▼
┌─────────────────────────────┐
│  Obsidian.app (running)     │
│  ├─ Vault index             │
│  ├─ Plugin runtime          │
│  │   ├─ Daily Notes         │
│  │   ├─ Templates           │
│  │   ├─ Templater (community)│
│  │   ├─ Dataview (community)│
│  │   └─ Tasks (community)   │
│  └─ Search index            │
└─────────────────────────────┘
```

The plugin is a **thin wrapper** over the official Obsidian CLI. We don't reimplement vault parsing, link resolution, frontmatter handling, search indexing, or any of Obsidian's core features. Instead, every command shells out to `obsidian <subcommand>`, parses the result, and renders it using Neovim's native UI primitives (pickers, buffers, quickfix).

## Why this architecture

### The trade-off in one sentence

**We trade headless capability for free access to Obsidian's entire ecosystem.**

### What we gain

Because the CLI talks to a running Obsidian app, every command we wrap inherits the app's full feature set:

- **Templates** (core + Templater) without writing templating code
- **Dataview** queries without parsing a query language
- **Search** with Obsidian's actual index, not regex over files
- **Frontmatter** with Obsidian's typed property system
- **Sync history** via `obsidian diff` / `obsidian sync:*`
- **Bases** (Obsidian's database feature) via `obsidian bases`
- **Tags, backlinks, unresolved links** from Obsidian's link graph
- **Updates** — when Obsidian ships a new feature, the CLI exposes it; we get it for free

Each of those is hundreds-to-thousands of lines of code we **don't have to write**.

### What we give up

- **Headless operation** — the Obsidian app must be running. The CLI is a remote control client; without the server (the app), it has nothing to talk to.
- **First-launch latency** — a cold app boot takes ~2 seconds before commands work
- **Memory footprint** — Obsidian uses ~300-500 MB of RAM
- **Server-side use** — can't run this on a headless SSH session or in a Docker container
- **Crash propagation** — if Obsidian crashes, the CLI dies with it

For most users, these trade-offs are acceptable. The mitigation is to add Obsidian to OS login items so it's always running in the background.

### Why not pure Lua?

The pure-Lua approach (used by `obsidian-nvim/obsidian.nvim`) has the opposite trade-off: works headlessly but reimplements ~5000 lines of vault-handling logic and never inherits new Obsidian features. That's a perfectly valid choice — but it's a different plugin solving a different problem.

If you need headless support today, use `obsidian-nvim/obsidian.nvim`. If you want the live app's power and don't mind keeping it running, use this plugin.

## Module breakdown

### `lua/obsidian-cli/init.lua`

The setup entry point. Merges user config with defaults, registers commands and keymaps, sets up the autocmds for buffer-scoped behavior.

Responsibilities:
- `M.setup(opts)` — public API
- Global keymap registration
- Vault buffer detection autocmd (FileType + BufWinEnter + BufFilePost + BufWritePost)
- Buffer-local options application (wrap, linebreak, etc.)
- Diagnostics scoping (when enabled in config)

### `lua/obsidian-cli/config.lua`

Default config table and merge logic. Pure data — no side effects.

### `lua/obsidian-cli/cli.lua`

The single point of contact with the `obsidian` binary. Every other module that needs CLI data goes through here.

Responsibilities:
- `M.run({args})` — synchronous shell-out via `vim.system`. Detects stdout-as-error patterns (the CLI returns errors on stdout with exit code 0 sometimes — see Quirks below).
- `M.run_json({args})` — wrapper that parses stdout as JSON, handles "No X found." as empty result instead of parse error.
- `M.vault_path()` — auto-detects the vault path via `obsidian vault info=path`, with caching.
- `M.version()` — returns the CLI version string.
- `M.reset_vault_cache()` — invalidates the vault path cache.

### `lua/obsidian-cli/util.lua`

Pure path manipulation helpers. No CLI calls, no Neovim API beyond `vim.startswith` and `vim.split`.

Responsibilities:
- `M.absolute(rel, vault_path)` — convert vault-relative to absolute
- `M.relative_to_vault(abs, vault_path)` — convert absolute to vault-relative
- `M.in_vault(path, vault_path)` — predicate
- `M.split_lines(s)` — newline-split with empty-line trimming
- `M.expand(path)` — `~` expansion

### `lua/obsidian-cli/commands.lua`

The 44 user commands (`:Obsidian*`). Each command:

1. Calls `cli.run` or `cli.run_json` to fetch data from the CLI
2. Builds picker items or dispatches in-buffer edits
3. Handles errors via `notify_error` with friendly hints

Some commands prefer in-buffer edits over CLI round-trips for instant feedback:
- `:ObsidianTaskToggle` — pure buffer edit (regex swap)
- `:ObsidianTask` / `:ObsidianTodo` / `:ObsidianAppend` — in-buffer append if today's note is open, CLI fallback otherwise

### `lua/obsidian-cli/pickers/init.lua`

Adapter dispatcher. Auto-detects which picker backend to use:
1. Snacks if `snacks.nvim` is installed
2. Quickfix as fallback

Two main entry points:
- `M.pick(items, opts)` — static item list
- `M.live_search(opts)` — finder callback for live-updating searches

### `lua/obsidian-cli/pickers/snacks.lua`

Snacks adapter. Two functions:
- `M.files(items, opts)` — opens a static picker with file preview
- `M.live_search(opts)` — opens a live picker with finder callback

Custom previewer handles empty files gracefully (shows `(empty file)` instead of Snacks's default debug dump).

### `lua/obsidian-cli/pickers/quickfix.lua`

Quickfix fallback. Single function `M.files(items, opts)` that builds a quickfix list and opens it. No live-search support — quickfix is inherently static.

### `lua/obsidian-cli/completion/blink.lua`

`blink.cmp` source for vault-aware `[[wiki link]]` completion. Implements:
- `source.new(opts)` — constructor
- `source:get_trigger_characters()` — returns `{ "[" }`
- `source:enabled()` — returns true only inside vault markdown buffers
- `source:get_completions(ctx, callback)` — extracts the partial query, fetches vault files, builds completion items

Includes file list cache (2-second TTL) and auto-pairs interop (consumes existing `]]` characters in the textEdit range).

### `lua/obsidian-cli/health.lua`

`:checkhealth obsidian-cli` implementation. Verifies the wrapper is in a working state by testing each layer of the stack.

## CLI quirks the wrapper defends against

The Obsidian CLI has a few non-obvious behaviors that require special handling:

### 1. Errors on stdout with exit code 0

`obsidian version`, `obsidian vault info=path`, etc. return error messages on stdout with exit code 0 instead of stderr with non-zero exit. The wrapper string-matches against known error patterns (`Vault not found.`, `The CLI is unable to find Obsidian.`, etc.) and converts them to proper errors regardless of exit code.

### 2. Plain text "No X found." instead of empty JSON

When a query has zero results, several commands return the literal string `No tasks found.` (or similar) instead of `[]`. The wrapper's `run_json` detects these patterns and returns an empty table — no JSON parse error.

### 3. Line numbers as strings in JSON

`obsidian tasks format=json` returns `"line": "2"` (string), not `"line": 2` (number). Snacks's filename formatter expects integers. The wrapper coerces with `tonumber()` everywhere it reads line numbers from CLI JSON.

### 4. Broken filter combinations

`obsidian tasks daily todo` returns "No tasks found." even when tasks exist. The `todo` filter is broken when combined with `daily`. Workaround: drop `todo`, fetch all daily tasks, filter to incomplete (`status == " "`) in Lua.

### 5. `sources` is a string for one-result, possibly comma-separated for multi-result

`obsidian unresolved format=json verbose` returns `"sources": "Welcome.md"` (string) for a single source. The wrapper splits on comma and handles both string and table shapes defensively.

### 6. CLI's documented auto-launch doesn't actually work

The [official Obsidian docs](https://help.obsidian.md/cli) state: *"If Obsidian is not running, the first command you run launches Obsidian."* In CLI v1.12.7 this is **false** for one-shot subcommands like `obsidian daily:path` — the command returns `The CLI is unable to find Obsidian.` and exits without launching the app.

We considered implementing our own auto-launch in the wrapper but ultimately rejected it because:

1. **Launching a GUI app silently is platform-specific and unreliable.** macOS has `open -gj` and AppleScript `launch`; Linux has DE-dependent conventions and inconsistent `--minimized` flag support; Windows can only use `start /min` which still flashes the window. There is no clean cross-platform "launch invisibly" API.
2. **It would dump us into an OS-specific maintenance hole** — every platform's launch quirks become our problem, and they change between OS versions.
3. **Login items solve the same problem more cleanly.** Setting Obsidian to launch at login is a one-time user action that makes auto-launch unnecessary.
4. **Being honest about the requirement is better UX than fighting it.** A clear error with a fix-it hint beats a silent slow command that sometimes fails for unclear reasons.

The plugin's approach: error loudly with a friendly hint when Obsidian isn't running, ship a `:ObsidianStart` command for one-keystroke manual launching, and document the recommended login-items setup in the README.

## On Obsidian Headless

Obsidian publishes a separate product called **Obsidian Headless** which runs without a GUI. We do NOT use it because:

- It's a sync-only client (server deployments, automated backups)
- It does not expose the CLI command set we depend on (no `daily:path`, `tasks`, `backlinks`, `search:context`, etc.)
- Per Obsidian's own docs: *"Obsidian CLI controls the Obsidian desktop app from your terminal. Obsidian Headless is a standalone client that runs independently."*

There is no path within Obsidian's official tooling to a true headless plugin that exposes the CLI's full feature set. The desktop app (auto-launched or manually started) is the only way to access the CLI's commands.

## Lazy-loading behavior

The recommended install uses `event = "VeryLazy"` which loads the plugin
after Neovim's UI draws (~10-20ms cost). All 44 commands and keymaps
register during `setup()` and are available immediately. No `cmd` or
`keys` lists needed in the Lazy spec.

## Testing

The plugin ships 122 plenary tests across 12 spec files. See `docs/testing.md`
for the full spec file inventory, mock patterns, and `make test` instructions.

Tests mock `vim.system` to isolate the pure-Lua logic from the real CLI binary,
so they run in CI without Obsidian installed. Coverage includes all command
implementations, error handling, JSON parsing, wiki-link extraction, buffer
editing (task toggle, in-buffer append), confirmation flows, and the blink.cmp
completion source's enabled() + context detection.
