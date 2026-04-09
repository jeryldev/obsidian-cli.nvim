# obsidian-cli.nvim

> A thin Neovim wrapper for the **official Obsidian CLI**. Drives the live Obsidian app from inside Neovim — no Lua reimplementation of the vault format.

> 🚧 **Early version (`v0.0.x`).** Commands, configuration, and keymaps may change without notice until `v0.1.0`. Pin to a tag if you depend on stability.

## Why this and not [`obsidian-nvim/obsidian.nvim`](https://github.com/obsidian-nvim/obsidian.nvim)?

The two plugins serve **genuinely different audiences**. Pick based on whether you're willing to keep the Obsidian desktop app running.

| | `obsidian-cli.nvim` (this) | `obsidian-nvim/obsidian.nvim` |
|---|---|---|
| **Implementation** | Thin wrapper over the official `obsidian` CLI | Pure Lua reimplementation, ~4-5k LOC |
| **Lines of code** | ~2,000 | ~4,000-5,000 |
| **Commands shipped** | 30 (daily-driver flows + plugin management + escape hatch + Bases) | 28 (full feature set) |
| **Test coverage** | 60 plenary tests across util/config/cli/setup | Community-tested, no bundled suite |
| **Requires Obsidian app running** | Yes — the CLI is a remote control for the live app | No — works fully headless |
| **Vault discovery** | Auto-detected via `obsidian vault info=path` | Requires explicit `workspaces` config |
| **Search** | Uses Obsidian's actual search index (knows aliases, tags, link semantics) | Uses ripgrep (pure regex over file content) |
| **Backlinks** | Obsidian's link graph (instant, cached by the app) | ripgrep on-demand (re-scans vault each request) |
| **Templates** | Obsidian core Templates + Templater community plugin (full JS template runtime) | Custom `{{variable}}` string substitution only |
| **Daily notes path/format** | Read at runtime from your Obsidian Settings | Plugin-side `daily_notes` config (must duplicate) |
| **Frontmatter** | Obsidian's typed property system | Custom Lua YAML parser |
| **Templates** (Obsidian core) | Used by `:ObsidianNewFrom` today | Custom `{{var}}` substitution only |
| **Templater, Dataview, Tasks, Periodic Notes** | Reachable via `:ObsidianCommand`/`:ObsidianCommandList` escape hatch (dedicated wrappers planned for v0.1.0 if you install the plugins) | Not accessible — these live in Obsidian's JavaScript runtime |
| **Bases** (Obsidian core DB feature) | Wrapped: `:ObsidianBases`, `:ObsidianBaseViews`, `:ObsidianBaseQuery`, `:ObsidianBaseCreate` | Not accessible — Bases is Obsidian-native |
| **Plugin management** (install, enable, disable, reload) | Wrapped: `:ObsidianPluginList` and CRUD commands — install community plugins from Neovim | Not applicable — doesn't use Obsidian's plugin ecosystem |
| **Performance ceiling** | Bound by Obsidian app speed | Slows past ~5,000 markdown files (no persistent index) |
| **Update cadence** | Inherits new features from Obsidian releases | Community-maintained, manual feature parity |
| **First-launch cost** | Cold-boot Obsidian (~2s) if not already running | Instant |
| **Works on headless server / SSH / no display** | No | Yes |

### Pick `obsidian-cli.nvim` if:
- You have Obsidian installed and don't mind keeping it running in the background
- You want **Obsidian's real search index** (knows aliases, tags, link semantics — not just regex over files)
- You want **real backlinks** from Obsidian's link graph (cached by the app, not re-scanned per request)
- You want the plugin to **just work** without configuring vault paths or daily-note formats — it reads them from Obsidian
- You value a small, focused codebase (~1,500 LOC) that inherits new Obsidian features as the CLI exposes them
- You want the *option* to call into Templater/Dataview/Tasks/Bases via the CLI's escape hatch (dedicated wrappers planned for v0.1.0)

### Pick `obsidian-nvim/obsidian.nvim` if:
- You need the plugin to work **without the Obsidian desktop app running** (SSH, headless server, battery-conscious use, no-GUI environments)
- You don't use Templater, Dataview, Tasks, or Bases — basic markdown and wiki links are enough
- You're OK with explicit vault configuration and a custom YAML/template parser

## Features

### Daily-driver workflow
- **Daily notes** — open today, append tasks, list incomplete tasks, all from inside Neovim
- **Task toggling** — `<leader>oc` to toggle the checkbox on the current line
- **In-buffer edits** — task capture, toggling, and note creation happen instantly without disk round-trips

### Note navigation
- **Vault-aware [[wiki link]] completion** via blink.cmp — autocomplete from your real vault notes
- **Follow wiki links** — `<leader>ol` to jump to the note under cursor; offers to create it if missing
- **Live full-text search** — Snacks picker that updates as you type
- **Backlinks & unresolved links** — surface broken links and resolve them with one keystroke
- **Recent & find pickers** — browse vault notes with preview pane

### Note creation
- **Note creation from templates** — `:ObsidianNewFrom` uses your Obsidian template setup
- **Resolve broken links** — `<leader>oR` creates a note from the `[[link]]` under cursor

### Plugin & command management *(new in v0.0.4)*
- **Plugin browser** — `:ObsidianPluginList` with action menu (enable/disable/uninstall/reload/info)
- **Install plugins from Neovim** — `:ObsidianPluginInstall <id>`, `:ObsidianPluginUninstall <id>`, etc.
- **Restricted mode** — `:ObsidianRestrictedMode on/off` to toggle Obsidian's safe mode
- **Generic command runner** — `:ObsidianCommandList` picker to run any Obsidian command (Templater, Dataview, etc.)

### Bases *(new in v0.0.4)*
- **Database views** — `:ObsidianBases`, `:ObsidianBaseViews`, `:ObsidianBaseQuery`, `:ObsidianBaseCreate`
- Native Obsidian database tables exposed as Neovim pickers

### Developer experience
- **Auto-pairs interop** — wiki link completion plays nice with mini.pairs / nvim-autopairs
- **Confirmation prompts** — destructive actions (disable/uninstall) prompt before proceeding
- **Health check** — `:checkhealth obsidian-cli` diagnoses the entire stack
- **60+ automated tests** — plenary-based unit test suite with CI integration

## Requirements

1. **Obsidian desktop app**, version **1.12.0+** ([download](https://obsidian.md/download))
2. **Obsidian CLI enabled** via `Settings → General → Command line interface` (must register and add to PATH)
3. **The Obsidian app must be running when you invoke any command.** The Obsidian CLI is a remote control client that talks to the live desktop app over IPC. Without the app running, every command will fail with `The CLI is unable to find Obsidian.` See the [official Obsidian CLI documentation](https://help.obsidian.md/cli) for details.
4. **Neovim 0.10+** (uses `vim.system`, `vim.diagnostic.is_enabled`)

> ⚠️ **The plugin does not auto-launch Obsidian.** Trying to launch a GUI app silently is platform-dependent and unreliable. Instead, the plugin treats Obsidian as an always-on background service that you set up once.

### Recommended setup: launch Obsidian at login

Add `Obsidian.app` to your OS startup items so it's always running in the background. After the one-time setup, you'll never see the "Obsidian not running" error again.

- **macOS:** `System Settings → General → Login Items & Extensions → Open at Login → +` → select `Obsidian.app`. Check the "Hide" box if you don't want the window to appear at login.
- **Linux:** depends on your desktop environment — typically `Settings → Startup Applications → Add` → command `obsidian` (or your package's launcher).
- **Windows:** `Settings → Apps → Startup → Obsidian → On`.

Also enable Obsidian's own "Open previous vaults on startup" setting (`Settings → About`) so the app boots straight into your vault rather than the vault picker.

### If Obsidian isn't running

When the plugin can't reach the app, it errors with a clear hint:

```
:ObsidianToday: The CLI is unable to find Obsidian.
Hint: launch the Obsidian desktop app (e.g. `open -a Obsidian`) and retry.
```

You can launch it from inside Neovim with `:ObsidianStart` (cross-platform — runs the appropriate launcher for your OS) and retry the command.

## Install

### lazy.nvim

```lua
{
  "jeryldev/obsidian-cli.nvim",
  ft = "markdown",
  cmd = {
    -- Daily notes & tasks
    "ObsidianToday", "ObsidianTask", "ObsidianTodo", "ObsidianAppend",
    "ObsidianTasksToday", "ObsidianTaskToggle",
    -- Note creation & navigation
    "ObsidianNew", "ObsidianNewFrom",
    "ObsidianFind", "ObsidianRecent", "ObsidianSearch",
    "ObsidianBacklinks", "ObsidianUnresolved",
    "ObsidianResolveLink", "ObsidianFollowLink",
    -- App control
    "ObsidianStart",
    -- Generic command runner (escape hatch for community plugins)
    "ObsidianCommand", "ObsidianCommandList",
    -- Plugin management
    "ObsidianPluginList", "ObsidianPluginInstall", "ObsidianPluginUninstall",
    "ObsidianPluginEnable", "ObsidianPluginDisable", "ObsidianPluginReload",
    "ObsidianPluginInfo", "ObsidianRestrictedMode",
    -- Bases (core database feature)
    "ObsidianBases", "ObsidianBaseViews", "ObsidianBaseQuery", "ObsidianBaseCreate",
  },
  opts = {},
}
```

After installing, run `:checkhealth obsidian-cli` to verify everything is wired up.

### Wiki link completion (optional but recommended)

Add a blink.cmp source override:

```lua
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
}
```

See [docs/completion.md](docs/completion.md) for the full setup including suppressing other sources inside `[[...]]`.

## 30-second tour

```vim
<leader>ot           " Open today's daily note
<leader>oT buy milk  " Append a task to today's note
<leader>ox           " Show today's incomplete tasks
<leader>oc           " Toggle the task on the current line
<leader>fo           " Find any note (Snacks picker)
<leader>os           " Live full-text search
<leader>on Trip      " Create a new note titled "Trip"
<leader>ob           " Show backlinks for the current note
<leader>ou           " Show unresolved [[wiki links]]
<leader>ol           " Follow [[link]] under cursor (create if missing)
<leader>oR           " Force-create a note from the [[link]] under cursor
```

In a vault markdown file, type `[[` to get vault-aware autocompletion of all your notes.

### Plus, manage Obsidian from Neovim

```vim
:ObsidianPluginList                    " Browse installed plugins + enable/disable/uninstall
:ObsidianPluginInstall templater-obsidian
:ObsidianCommandList                   " Pick from every registered Obsidian command
:ObsidianCommand app:reload            " Run a specific Obsidian command directly
:ObsidianRestrictedMode on             " Toggle safe mode (disable all community plugins)
:ObsidianBases                         " Browse .base files (Obsidian's database feature)
```

## Documentation

Full reference docs live in [`docs/`](docs/):

- **[Commands](docs/commands.md)** — every `:Obsidian*` command, what it does, what it wraps
- **[Configuration](docs/configuration.md)** — full `setup()` options reference
- **[Completion](docs/completion.md)** — wiki link completion via blink.cmp
- **[Troubleshooting](docs/troubleshooting.md)** — common issues and fixes
- **[Architecture](docs/architecture.md)** — design decisions and CLI quirks (for contributors)
- **[Testing](docs/testing.md)** — writing and running the plenary test suite

## What's new in v0.0.4

- **15 new commands** across escape hatch, plugin management, Bases, and link navigation
- **`:ObsidianPluginList`** — browse installed plugins with an action menu (enable/disable/uninstall/reload/info)
- **`:ObsidianCommand` / `:ObsidianCommandList`** — escape hatch to run any registered Obsidian command, unlocks every community plugin
- **`:ObsidianFollowLink`** / `<leader>ol` — smart follow of `[[wiki links]]` with create-if-missing prompt
- **Bases wrappers** — `:ObsidianBases`, `:ObsidianBaseViews`, `:ObsidianBaseQuery`, `:ObsidianBaseCreate`
- **`:ObsidianRestrictedMode`** — toggle Obsidian's safe mode (plus a banner in `:ObsidianPluginList` when active)
- **Confirmation prompts** on destructive actions (disable, uninstall)
- **`recent_limit` config option** — control how many entries `:ObsidianRecent` shows
- **Windows path support** — `is_absolute` now recognizes `C:\`, `C:/`, etc.
- **60-test plenary suite** with `make test`, GitHub Actions CI integration

See the full v0.0.4 [commands reference](docs/commands.md) for details.

## Roadmap

Planned for `v0.1.0`:

- `:ObsidianYesterday`, `:ObsidianTomorrow`, `:ObsidianPrependToday`
- `:ObsidianTags` / `:ObsidianTag <name>` tag browser
- `:ObsidianRename`, `:ObsidianMove`, `:ObsidianDelete` (destructive, with confirmations)
- `:ObsidianOpenInApp` (open current note in the Obsidian app window)
- `:ObsidianOutline` (heading picker for the current note)
- `:ObsidianLinks`, `:ObsidianOrphans`, `:ObsidianDeadends` (link-graph auditing)
- `:ObsidianRecentlyOpened` (Obsidian's internal recency list, complements mtime-based `:ObsidianRecent`)
- `:ObsidianTemplates` / `:ObsidianTemplateInsert` (core Templates picker)
- `:ObsidianProperties` / `:ObsidianPropertySet` (typed frontmatter editing)
- `:ObsidianWorkspace` (multi-vault switching)
- `:ObsidianDiff` (CLI sync history viewer — requires Obsidian Sync)
- `:ObsidianEval {js}` (raw JavaScript escape hatch)
- `gf` passthrough for `[[wiki]]` and `[markdown](links)`
- `<CR>` smart action (toggle checkbox / follow link)
- Telescope and fzf-lua picker adapters
- Display-text alias completion (`[[Note|alias]]`)
- Heading and block reference completion (`[[Note#heading]]`)
- Dedicated wrappers for Templater / Dataview / Tasks / Periodic Notes (when installed)
- Keymap reorganization with sub-prefixes (task group under `<leader>ot*`)

Considering for later:

- Headless mode for offline / SSH use (filesystem-based fallback for commands that don't need the index)
- `:ObsidianBookmark` / bookmarks browser
- Image paste integration with `img-clip.nvim`
- Picker preview rendering for markdown files via render-markdown.nvim

## References

- **Official Obsidian CLI documentation:** [help.obsidian.md/cli](https://help.obsidian.md/cli)
- **Obsidian CLI overview & install:** [obsidian.md/cli](https://obsidian.md/cli)
- **Obsidian Headless** (separate sync-only product, not used by this plugin): [help.obsidian.md/obsidian-headless](https://help.obsidian.md/obsidian-headless)
- **Obsidian app download:** [obsidian.md/download](https://obsidian.md/download)
- **Obsidian community plugins:** [obsidian.md/plugins](https://obsidian.md/plugins) — Templater, Dataview, Tasks, Periodic Notes, etc. all work via `obsidian command id=...` (planned for v0.1.0)

## Contributing

Issues and PRs welcome at [github.com/jeryldev/obsidian-cli.nvim](https://github.com/jeryldev/obsidian-cli.nvim).

Until `v0.1.0`, expect breaking changes. Pin to a specific tag if you need stability.

See [docs/architecture.md](docs/architecture.md) for the module breakdown and design rationale before submitting PRs.

## License

MIT
