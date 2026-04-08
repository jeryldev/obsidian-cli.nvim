# obsidian-cli.nvim

> A thin Neovim wrapper for the **official Obsidian CLI**. Drives the live Obsidian app from inside Neovim — no Lua reimplementation of the vault format.

> 🚧 **Early version (`v0.0.1`).** Commands, configuration, and keymaps may change without notice until `v0.1.0`. Pin to a tag if you depend on stability.

## Why this and not [`obsidian-nvim/obsidian.nvim`](https://github.com/obsidian-nvim/obsidian.nvim)?

| | `obsidian-cli.nvim` (this) | `obsidian-nvim/obsidian.nvim` |
|---|---|---|
| **Implementation** | Wraps the official `obsidian` CLI | Pure Lua reimplementation |
| **Requires Obsidian app running** | Yes | No |
| **Frontmatter handling** | Delegated to Obsidian | Custom Lua parser |
| **Templates** | Obsidian's templates + Templater plugin | Custom Lua templates |
| **Search** | Uses Obsidian's index | Uses ripgrep |
| **Plugin ecosystem (Dataview, Tasks, Templater)** | Available via `obsidian command` (planned) | Not accessible |
| **Works headless / no GUI** | No (needs running app) | Yes |
| **LOC** | ~500 | ~5000+ |
| **Update cadence** | Inherits from Obsidian releases | Community-maintained |

**Pick this if:** you have Obsidian installed and want the editing power of Neovim with the indexing/templating/plugin power of the live Obsidian app.

**Pick the other one if:** you don't run the Obsidian desktop app, or you want a pure-Lua solution that works headlessly.

## Requirements

1. **Obsidian desktop app**, version **1.12.0+** ([download](https://obsidian.md/download))
2. **Obsidian CLI enabled** via `Settings → General → Command line interface` (must register and add to PATH)
3. **Obsidian app must be running** when invoking commands — the CLI is a remote control for the live app
4. **Neovim 0.10+** (uses `vim.system`)

Run `:checkhealth obsidian-cli` after install to verify everything is wired up.

## Install

### lazy.nvim

```lua
{
  "jeryldev/obsidian-cli.nvim",
  ft = "markdown",
  cmd = {
    "ObsidianToday",
    "ObsidianTask",
    "ObsidianTodo",
    "ObsidianAppend",
    "ObsidianTasksToday",
    "ObsidianNew",
    "ObsidianNewFrom",
    "ObsidianFind",
    "ObsidianRecent",
    "ObsidianSearch",
    "ObsidianBacklinks",
    "ObsidianUnresolved",
  },
  opts = {},
}
```

## Commands

| Command | What it does |
|---|---|
| `:ObsidianToday` | Open today's daily note in Neovim |
| `:ObsidianTask {text}` | Append `- [ ] {text}` to today's daily note |
| `:ObsidianTodo {text}` | Alias of `:ObsidianTask` |
| `:ObsidianAppend {text}` | Append plain `{text}` to today's daily note |
| `:ObsidianTasksToday` | Show today's incomplete tasks (quickfix) |
| `:ObsidianNew {title}` | Create a new note |
| `:ObsidianNewFrom {template} {title}` | Create a new note from a template |
| `:ObsidianFind` | Pick a note from the vault (picker) |
| `:ObsidianRecent` | Pick from recently modified notes (picker) |
| `:ObsidianSearch {query}` | Full-text search the vault (picker) |
| `:ObsidianBacklinks` | Show backlinks for the current note (picker) |
| `:ObsidianUnresolved` | List unresolved `[[wiki]]` links (quickfix) |

## Default keymaps

Set `keymaps = false` in setup to opt out and wire your own.

### Global

| Keymap | Command |
|---|---|
| `<leader>ot` | `:ObsidianToday` |
| `<leader>oT` | `:ObsidianTask ` |
| `<leader>oa` | `:ObsidianAppend ` |
| `<leader>on` | `:ObsidianNew ` |
| `<leader>oN` | `:ObsidianNewFrom ` |
| `<leader>of` | `:ObsidianFind` |
| `<leader>or` | `:ObsidianRecent` |
| `<leader>os` | `:ObsidianSearch ` |
| `<leader>ox` | `:ObsidianTasksToday` |
| `<leader>ou` | `:ObsidianUnresolved` |

### Buffer-local (vault markdown only)

| Keymap | Command |
|---|---|
| `<leader>ob` | `:ObsidianBacklinks` |

## Configuration

Defaults — pass any subset to `setup()`:

```lua
require("obsidian-cli").setup({
  -- Path to the obsidian binary (override if not on PATH)
  binary = "obsidian",

  -- Target a specific vault by name. nil = use Obsidian's currently active vault.
  vault = nil,

  -- Explicit vault path. nil = auto-detect via `obsidian vault info=path`.
  -- Used for buffer-scoped keymaps and to absolutize vault-relative paths.
  vault_path = nil,

  -- Picker backend: "snacks", "quickfix", or nil to auto-detect.
  picker = nil,

  -- Register default keymaps. Set false to wire your own.
  keymaps = true,

  -- Buffer-local options applied to markdown files inside the vault.
  -- Set to false to leave buffers untouched.
  buffer_options = {
    wrap = true,
    linebreak = true,
    breakindent = true,
    colorcolumn = "80",
    spell = true,
    conceallevel = 2,
  },
})
```

## `:checkhealth obsidian-cli`

Verifies:

1. The `obsidian` binary is on PATH and reports a version
2. The Obsidian app is running (the CLI requires a live app for most commands)
3. The active vault is reachable
4. JSON output works for the commands the plugin parses

If `:checkhealth` passes, every command in this plugin should work.

## Pickers

`obsidian-cli.nvim` ships with two adapters in `v0.0.1`:

- **Snacks** — used automatically if `snacks.nvim` is installed
- **Quickfix** — fallback that works everywhere

Telescope and fzf-lua adapters are planned for `v0.1.0`.

## Roadmap

Planned for `v0.1.0`:

- `:ObsidianYesterday`, `:ObsidianTomorrow`
- `:ObsidianTags` browser
- `:ObsidianRename`, `:ObsidianMove`, `:ObsidianDelete`
- `:ObsidianOpen` (open current note in the Obsidian app)
- `:ObsidianWorkspace` (multi-vault switching)
- `:ObsidianDiff` (CLI sync history viewer)
- `:ObsidianCommand {id}` (run any registered Obsidian command — unlocks Templater, Dataview, Tasks)
- `:ObsidianEval {js}` (raw JavaScript escape hatch)
- `gf` passthrough for `[[wiki]]` and `[markdown](links)`
- `<CR>` smart action (toggle checkbox / follow link)
- `<leader>ch` toggle current task
- Telescope and fzf-lua picker adapters
- Native CLI sort once `obsidian files sort=` is supported

Planned for later:

- `:ObsidianBookmark` / bookmarks browser
- Outline picker via `obsidian outline format=json`
- Bases support (`obsidian bases`, `base:query`)
- Image paste integration with `img-clip.nvim`

## Contributing

Issues and PRs welcome. Until `v0.1.0`, expect breaking changes.

## License

MIT
