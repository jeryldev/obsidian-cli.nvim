# Commands

Every user command exposed by `obsidian-cli.nvim` as of v0.0.4. All commands prefix with `:Obsidian` and are dispatched through the official Obsidian CLI to your running Obsidian app.

**Command count:** 30 total across 6 categories.

## Daily notes

### `:ObsidianToday`

Open today's daily note in the current buffer. If the note is already loaded in a buffer, switches to that buffer instead of re-reading from disk. Requires Obsidian's core "Daily notes" plugin to be enabled (ships enabled in default installs).

- **Default keymap:** `<leader>ot`
- **Wraps:** `obsidian daily:path`
- **Notes:** the date format and folder come from your Obsidian Settings → Core plugins → Daily notes configuration. The plugin reads them at runtime and respects whatever you configure on the Obsidian side.

### `:ObsidianTask {text}`

Append a checkbox-prefixed task to today's daily note: `- [ ] {text}`. If today's note is already loaded in a buffer, the append happens **in place** in that buffer (instant visual feedback) and the cursor jumps to the end of the new line. If the buffer isn't open, the append goes through the CLI's disk-write path.

- **Default keymap:** `<leader>oT`
- **Wraps:** in-buffer edit, or `obsidian daily:append content="- [ ] {text}"`
- **Example:** `:ObsidianTask buy groceries` appends `- [ ] buy groceries`

### `:ObsidianTodo {text}`

Alias of `:ObsidianTask`. Same behavior, different name for users who prefer "todo" terminology.

### `:ObsidianAppend {text}`

Append plain `{text}` to today's daily note (no checkbox prefix). Useful for log entries, meeting notes, or quick captures that aren't tasks.

- **Default keymap:** `<leader>oa`
- **Wraps:** in-buffer edit, or `obsidian daily:append content="{text}"`

### `:ObsidianTasksToday`

Open a picker showing today's incomplete tasks. Selecting an entry jumps to that task in today's note.

- **Default keymap:** `<leader>ox`
- **Wraps:** `obsidian tasks daily format=json`, filtered Lua-side to incomplete (`status == " "`) tasks
- **Note:** the CLI's `tasks daily todo` filter combo is broken (returns "No tasks found." even when tasks exist), so the wrapper fetches all daily tasks and filters incomplete ones in Lua.

## Note creation

### `:ObsidianNew {title}`

Create a new note with the given title. After creation, the new file opens in the current buffer.

- **Default keymap:** `<leader>on`
- **Wraps:** `obsidian create name={title}`
- **Example:** `:ObsidianNew Trip to Paris` creates `Trip to Paris.md` in the vault root

### `:ObsidianNewFrom {template} {title}`

Create a new note from a template. Requires Obsidian's core Templates plugin (or the Templater community plugin) to be configured.

- **Default keymap:** `<leader>oN`
- **Wraps:** `obsidian create name={title} template={template}`
- **Example:** `:ObsidianNewFrom daily Q1 Review` creates a new note named "Q1 Review" using the "daily" template
- **Setup:** enable Templates in Obsidian Settings → Core plugins → Templates, set a template folder, create template `.md` files

## Finding & navigating

### `:ObsidianFind`

Pick any note in the vault from a fuzzy-searchable picker. Selecting a note opens it in the current buffer.

- **Default keymaps:** `<leader>of`, `<leader>fo`
- **Wraps:** `obsidian files`
- **Picker:** Snacks (preferred) or quickfix (fallback)

### `:ObsidianRecent`

Pick from notes sorted by most-recently-modified. Limited to the number configured by `recent_limit` (default 20).

- **Default keymap:** `<leader>or`
- **Config:** `recent_limit = 20` — raise to show more, lower to show fewer
- **Implementation:** calls `obsidian files`, then sorts by `mtime` Lua-side using `vim.uv.fs_stat`. The CLI's `sort=` flag isn't supported as of v1.12.7, so the wrapper does the sort itself.

### `:ObsidianSearch [{query}]`

Full-text search the vault. Two modes:

- **Live mode** (no argument) — picker opens immediately with an empty result list. Type into the search box and results populate as you type, sourced from `obsidian search:context`. This is the default behavior of `<leader>os`.
- **One-shot mode** (with argument) — runs the query once and shows static results. Useful for scripting: `:ObsidianSearch meeting notes`.

- **Default keymap:** `<leader>os` (opens live mode)
- **Wraps:** `obsidian search:context query={query} format=json`
- **Picker:** Snacks only for live mode (quickfix fallback can't do live search). One-shot mode works with both pickers.

### `:ObsidianBacklinks`

Show all notes that link to the current note. Buffer-local — only meaningful when editing a vault file.

- **Default keymap:** `<leader>ob` (buffer-local in vault markdown)
- **Wraps:** `obsidian backlinks path={current_file_relative_to_vault} format=json`
- **Note:** "No backlinks found." from the CLI is treated as an empty result, not an error.

### `:ObsidianUnresolved`

List all `[[wiki links]]` in the vault whose target file doesn't exist. Selecting an entry jumps to the source file with the cursor positioned **inside** the broken link, ready for `:ObsidianResolveLink` or `:ObsidianFollowLink`.

- **Default keymap:** `<leader>ou`
- **Wraps:** `obsidian unresolved format=json verbose`

## Editing tasks & links

### `:ObsidianTaskToggle`

Toggle the checkbox state of the task on the current line. `[ ]` ↔ `[x]`. Buffer-local in vault markdown.

- **Default keymap:** `<leader>oc` (buffer-local in vault markdown)
- **Implementation:** in-place buffer edit via `nvim_buf_set_lines`. Doesn't go through the CLI to avoid file-watcher race conditions.
- **Errors with:** "no checkbox on this line" if the cursor isn't on a `- [ ]` or `- [x]` line.

### `:ObsidianFollowLink` *(v0.0.4)*

Follow the `[[wiki link]]` under the cursor. If the target note exists, opens it in the current buffer. If it doesn't exist, prompts to create it (default Yes, so pressing Enter creates).

- **Default keymap:** `<leader>ol` (buffer-local in vault markdown)
- **Wraps:** `obsidian files` (for resolution) + `obsidian create` (for creation)
- **Handles:**
  - Plain links: `[[Welcome]]` → opens `Welcome.md`
  - Path links: `[[folder/note]]` → opens `folder/note.md`
  - Basename fallback: `[[note]]` → matches any `*/note.md` in the vault (case-insensitive)
  - Aliased links: `[[Note|Display]]` → resolves `Note`
  - Heading refs: `[[Note#Section]]` → resolves `Note`
  - Block refs: `[[Note^block-id]]` → resolves `Note`
- **Confirmation:** default-Yes so pressing Enter at the "create?" prompt creates the note.

### `:ObsidianResolveLink`

Force-create a new note from the `[[wiki link]]` under the cursor, without checking if it already exists. Designed for bulk-resolving broken links from `:ObsidianUnresolved`.

- **Default keymap:** `<leader>oR` (buffer-local in vault markdown)
- **Wraps:** `obsidian create name={link_text}`
- **Handles:** same alias/heading/block-ref stripping as `:ObsidianFollowLink`
- **Difference from `:ObsidianFollowLink`:** always creates, never navigates. Use this when you're working through `:ObsidianUnresolved` and know you want to create the target. Use `:ObsidianFollowLink` for general navigation.
- **Errors with:** CLI error if the file already exists (from `obsidian create` itself).

## App control

### `:ObsidianStart`

Launch the Obsidian desktop app from inside Neovim. Useful when you've quit Obsidian and want to bring it back without leaving your editor.

- **Wraps:** `open -a Obsidian` (macOS), `xdg-open obsidian://` (Linux), `obsidian://` URI (Windows)
- **Note:** the Obsidian CLI requires the desktop app to be running for almost all commands. Add Obsidian to your OS login items so it starts automatically.

## Escape hatch — run arbitrary Obsidian commands *(v0.0.4)*

### `:ObsidianCommand {id}` *(v0.0.4)*

Execute any registered Obsidian command directly by ID. This is the low-level entry point for triggering Obsidian actions that aren't wrapped by a dedicated `:Obsidian*` command — including commands exposed by community plugins (Templater, Dataview, Tasks, etc.).

- **Wraps:** `obsidian command id={id}`
- **Examples:**
  - `:ObsidianCommand app:reload` — reload Obsidian's UI silently
  - `:ObsidianCommand app:show-release-notes` — show the release notes panel
  - `:ObsidianCommand templater-obsidian:insert-template-modal` — invoke Templater's template picker (focus-stealing)
- **Discovery:** use `:ObsidianCommandList` to browse all available command IDs.

### `:ObsidianCommandList [{filter}]` *(v0.0.4)*

Browse and run any registered Obsidian command from a picker. Without arguments, shows all ~72 commands from core and community plugins. With an argument, filters by prefix.

- **Wraps:** `obsidian commands [filter={prefix}]` → Snacks picker
- **Examples:**
  - `:ObsidianCommandList` — all commands
  - `:ObsidianCommandList daily` — only commands starting with "daily"
  - `:ObsidianCommandList templater` — only Templater commands (if installed)
- **Picker:** uses the plugin's `pickers.select` helper. Snacks-preferred, with a `vim.fn.inputlist` fallback for non-Snacks setups or when Snacks's `vim.ui.select` override crashes.

## Plugin management *(v0.0.4)*

### `:ObsidianPluginList` *(v0.0.4)*

Browse all installed plugins (core + community) with an action menu. Each entry shows `✓` for enabled, `○` for disabled. Selecting an entry opens a second picker with actions: **Enable**, **Disable**, **Uninstall**, **Reload**, **Info**, or **Cancel**.

- **Wraps:** `obsidian plugins format=json versions` + `obsidian plugins:enabled format=json`
- **Banner:** if Restricted Mode is active, the picker title shows `⚠ RESTRICTED MODE ON (community plugins suspended)` so users know why community plugins appear as `○`.
- **Confirmation:** Disable and Uninstall actions prompt before proceeding. Default is No (destructive default).

### `:ObsidianPluginInfo {id}` *(v0.0.4)*

Show metadata for a specific plugin by ID (version, description, enabled state).

- **Wraps:** `obsidian plugin id={id}`
- **Example:** `:ObsidianPluginInfo zk-prefixer`

### `:ObsidianPluginInstall {id}` *(v0.0.4)*

Install a community plugin by ID and auto-enable it.

- **Wraps:** `obsidian plugin:install id={id} enable`
- **Example:** `:ObsidianPluginInstall templater-obsidian`
- **Finding IDs:** community plugin IDs match the GitHub repo name. Check [obsidian.md/plugins](https://obsidian.md/plugins) or use `:ObsidianPluginList` once a plugin is installed.

### `:ObsidianPluginUninstall {id}` *(v0.0.4)*

Uninstall a community plugin by ID. **Destructive** — prompts for confirmation before deleting the plugin's folder under `.obsidian/plugins/`. Default is No.

- **Wraps:** `obsidian plugin:uninstall id={id}`
- **Example:** `:ObsidianPluginUninstall templater-obsidian`

### `:ObsidianPluginEnable {id}` *(v0.0.4)*

Enable an installed plugin by ID.

- **Wraps:** `obsidian plugin:enable id={id}`
- **Example:** `:ObsidianPluginEnable zk-prefixer`

### `:ObsidianPluginDisable {id}` *(v0.0.4)*

Disable an installed plugin by ID. **Confirmed** — disabling a core plugin like `backlink` can silently break foundational Obsidian features, so the command prompts before proceeding. Default is No.

- **Wraps:** `obsidian plugin:disable id={id}`
- **Example:** `:ObsidianPluginDisable zk-prefixer`

### `:ObsidianPluginReload {id}` *(v0.0.4)*

Hot-reload a plugin by ID. Primarily useful for plugin developers — if you're editing a plugin's `main.js`, running this reloads the plugin without restarting Obsidian.

- **Wraps:** `obsidian plugin:reload id={id}`
- **Example:** `:ObsidianPluginReload my-plugin`

### `:ObsidianRestrictedMode [on|off]` *(v0.0.4)*

Toggle Obsidian's Restricted (safe) Mode. When on, ALL community plugins are disabled as a group. When off, they're restored to their previous enabled states. Without an argument, reports the current state.

- **Wraps:** `obsidian plugins:restrict [on|off]`
- **Use cases:**
  - Debug plugin conflicts ("does this break if I turn off all community plugins?")
  - Open an untrusted vault safely (all community plugins disabled until you explicitly re-enable)
  - Temporary performance boost (disable expensive plugins like Dataview during bulk edits)
- **Examples:**
  - `:ObsidianRestrictedMode` — query current state
  - `:ObsidianRestrictedMode on` — turn on safe mode
  - `:ObsidianRestrictedMode off` — restore community plugins
- **Indicator:** when restricted mode is ON, `:ObsidianPluginList` shows a warning banner in its picker title.

## Bases (database views) *(v0.0.4)*

Bases is Obsidian's core database feature (shipped in Obsidian 1.8+). A `.base` file defines a filter, columns, and views over your vault notes.

### `:ObsidianBases` *(v0.0.4)*

List all `.base` files in the vault as a picker. Selecting one opens it in the current buffer (you'll see raw YAML config — Bases's visual editor only works in the Obsidian app).

- **Wraps:** `obsidian bases`
- **Empty case:** notification "no .base files in vault" if the vault has no bases.

### `:ObsidianBaseViews [{base-path}]` *(v0.0.4)*

List views defined in a specific `.base` file. Without an argument, uses the currently-focused base in Obsidian.

- **Wraps:** `obsidian base:views [path={base-path}]`
- **Example:** `:ObsidianBaseViews projects.base` → prints view names

### `:ObsidianBaseQuery {base-path} {view}` *(v0.0.4)*

Query a specific view of a base and show matching notes in a picker.

- **Wraps:** `obsidian base:query path={base-path} view={view} format=paths`
- **Example:** `:ObsidianBaseQuery projects.base Active` → picker showing notes that match the "Active" view's filter
- **Usage note:** view names with spaces work — arguments are joined after the first two.

### `:ObsidianBaseCreate {base-path} {view} {name}` *(v0.0.4)*

Create a new row in a base. The row becomes a new `.md` note with frontmatter matching the base's schema.

- **Wraps:** `obsidian base:create path={base-path} view={view} name={name}`
- **Example:** `:ObsidianBaseCreate projects.base Active Migrate to Postgres`
- **Notes:** the name can contain spaces (arguments from the third onward are joined).

## Health check

### `:checkhealth obsidian-cli`

Verifies the wrapper is in a working state:

1. Plugin is loaded (`require("obsidian-cli")` succeeded)
2. `obsidian` binary is on PATH
3. Obsidian app is running (CLI can communicate with it)
4. A vault is loaded in the app
5. `obsidian files` returns valid output

If any line is red or yellow, the printed hint tells you how to fix it.

## Command summary table

| Command | Default keymap | Buffer scope | Picker? | Wave |
|---|---|---|---|---|
| `:ObsidianToday` | `<leader>ot` | global | no | v0.0.3 |
| `:ObsidianTask` | `<leader>oT` | global | no | v0.0.3 |
| `:ObsidianTodo` | — | global | no | v0.0.3 |
| `:ObsidianAppend` | `<leader>oa` | global | no | v0.0.3 |
| `:ObsidianTasksToday` | `<leader>ox` | global | yes | v0.0.3 |
| `:ObsidianNew` | `<leader>on` | global | no | v0.0.3 |
| `:ObsidianNewFrom` | `<leader>oN` | global | no | v0.0.3 |
| `:ObsidianFind` | `<leader>of`, `<leader>fo` | global | yes | v0.0.3 |
| `:ObsidianRecent` | `<leader>or` | global | yes | v0.0.3 |
| `:ObsidianSearch` | `<leader>os` | global | yes (live) | v0.0.3 |
| `:ObsidianBacklinks` | `<leader>ob` | vault markdown | yes | v0.0.3 |
| `:ObsidianUnresolved` | `<leader>ou` | global | yes | v0.0.3 |
| `:ObsidianTaskToggle` | `<leader>oc` | vault markdown | no | v0.0.3 |
| `:ObsidianResolveLink` | `<leader>oR` | vault markdown | no | v0.0.3 |
| `:ObsidianFollowLink` | `<leader>ol` | vault markdown | no | **v0.0.4** |
| `:ObsidianStart` | — | global | no | v0.0.3 |
| `:ObsidianCommand` | — | global | no | **v0.0.4** |
| `:ObsidianCommandList` | — | global | yes | **v0.0.4** |
| `:ObsidianPluginList` | — | global | yes | **v0.0.4** |
| `:ObsidianPluginInfo` | — | global | no | **v0.0.4** |
| `:ObsidianPluginInstall` | — | global | no | **v0.0.4** |
| `:ObsidianPluginUninstall` | — | global | no (confirm) | **v0.0.4** |
| `:ObsidianPluginEnable` | — | global | no | **v0.0.4** |
| `:ObsidianPluginDisable` | — | global | no (confirm) | **v0.0.4** |
| `:ObsidianPluginReload` | — | global | no | **v0.0.4** |
| `:ObsidianRestrictedMode` | — | global | no | **v0.0.4** |
| `:ObsidianBases` | — | global | yes | **v0.0.4** |
| `:ObsidianBaseViews` | — | global | no | **v0.0.4** |
| `:ObsidianBaseQuery` | — | global | yes | **v0.0.4** |
| `:ObsidianBaseCreate` | — | global | no | **v0.0.4** |

**Bold** = new in v0.0.4.
