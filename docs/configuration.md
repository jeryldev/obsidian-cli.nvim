# Configuration

All options passed to `require("obsidian-cli").setup(opts)`. Every option has a sensible default — `setup({})` works out of the box if Obsidian is running and a vault is loaded.

## Defaults

```lua
require("obsidian-cli").setup({
  -- Path to the obsidian binary. Override if not on your PATH.
  binary = "obsidian",

  -- Target a specific vault by name. nil = use Obsidian's currently active vault.
  -- Useful when you have multiple vaults and want to pin to one.
  vault = nil,

  -- Explicit vault path. nil = auto-detect via `obsidian vault info=path`.
  -- Used for buffer-scoped keymaps and to absolutize vault-relative paths.
  vault_path = nil,

  -- Picker backend: "snacks", "quickfix", or nil to auto-detect.
  -- Snacks is preferred when installed; quickfix is the fallback.
  picker = nil,

  -- Register default keymaps. Set false to wire your own.
  keymaps = true,

  -- Disable diagnostics inside vault markdown buffers (e.g. markdownlint
  -- noise about MD041, MD012). Set false to keep diagnostics enabled.
  disable_diagnostics_in_vault = true,

  -- Buffer-local options applied to markdown files inside the vault.
  -- Set false to leave buffers untouched.
  buffer_options = {
    wrap = true,
    linebreak = true,
    breakindent = true,
    colorcolumn = "80",
    spell = false,
    conceallevel = 2,
  },
})
```

## Option reference

### `binary`
- **Type:** `string`
- **Default:** `"obsidian"`
- **Purpose:** the executable name or absolute path to the Obsidian CLI binary. Override if `obsidian` isn't on your `PATH` or you want to pin a specific version.

### `vault`
- **Type:** `string | nil`
- **Default:** `nil`
- **Purpose:** vault name to target (matches the name shown in Obsidian's vault switcher). When set, every CLI invocation includes `vault=<name>` so commands operate on the specified vault even if Obsidian has a different vault in focus. Useful for multi-vault setups.

### `vault_path`
- **Type:** `string | nil`
- **Default:** `nil`
- **Purpose:** absolute path to the vault directory. When `nil`, the plugin auto-detects via `obsidian vault info=path` on first use. Set this explicitly if:
  - You want to skip the auto-detect step (saves one CLI call)
  - You're targeting a vault other than the currently active one in the app
  - You want vault detection to work even when the app starts without a vault loaded
- **Note:** `~` is expanded automatically.

### `picker`
- **Type:** `"snacks" | "quickfix" | nil`
- **Default:** `nil`
- **Purpose:** explicit picker backend. When `nil`, the plugin auto-detects: Snacks if `snacks.nvim` is installed, otherwise quickfix. Set explicitly to override the detection.
- **v0.0.x note:** only Snacks and quickfix adapters ship in v0.0.x. Telescope and fzf-lua adapters are planned for v0.1.0.

### `recent_limit`
- **Type:** `number`
- **Default:** `20`
- **Purpose:** maximum number of entries shown by `:ObsidianRecent`. The plugin enumerates all vault markdown files, sorts by mtime, and trims to this count. Raise if your vault is large and you want to browse deeper.

### `keymaps`
- **Type:** `boolean`
- **Default:** `true`
- **Purpose:** when `true`, the plugin registers default `<leader>o*` keymaps. Set `false` to opt out and wire your own.

### `disable_diagnostics_in_vault`
- **Type:** `boolean`
- **Default:** `true`
- **Purpose:** disables `vim.diagnostic` rendering for markdown buffers inside the vault. Default is on because most users find markdownlint warnings (MD041, MD012, etc.) noisy when writing personal notes. Set `false` to keep diagnostics active in vault buffers.
- **Scope:** only affects vault buffers. Markdown files outside the vault are untouched.

### `buffer_options`
- **Type:** `table | false`
- **Default:** see above
- **Purpose:** buffer-local options applied to markdown files inside the vault. Each key/value is set via `vim.api.nvim_set_option_value` with `scope = "local"`. Set the whole field to `false` to leave buffers untouched.

#### Default values explained

| Key | Default | Why |
|---|---|---|
| `wrap` | `true` | Soft-wrap long paragraphs at the window edge |
| `linebreak` | `true` | When wrapping, break at word boundaries instead of mid-word |
| `breakindent` | `true` | Wrapped lines visually align with their indent |
| `colorcolumn` | `"80"` | Visual guide at column 80 (no enforcement) |
| `spell` | `false` | Off by default — Vim's built-in spell flags too many false positives without a properly-loaded dictionary. Most users prefer Obsidian's own spell-check. |
| `conceallevel` | `2` | Lets render-markdown.nvim hide markdown syntax characters when rendering |

#### Customizing

To change the wrap column or enable hard-wrap instead of soft-wrap:

```lua
require("obsidian-cli").setup({
  buffer_options = {
    textwidth = 80,
    formatoptions = "tcqln",
    wrap = false,
    colorcolumn = "+1", -- shows the column 1 past textwidth
  },
})
```

To enable spell-check with a specific dictionary:

```lua
require("obsidian-cli").setup({
  buffer_options = {
    wrap = true,
    linebreak = true,
    spell = true,
    spelllang = "en_us",
  },
})
```

## Multi-vault setups

If you have more than one vault and want a per-machine default:

```lua
require("obsidian-cli").setup({
  vault = "Work",                              -- name as it appears in the app
  vault_path = "~/Documents/Vaults/Work",      -- explicit path for path-aware features
})
```

To switch vaults at runtime, you'd need to call `setup` again with different options. A cleaner runtime switcher is planned for v0.1.0 (`:ObsidianWorkspace`).

## Alternative: strict lazy-loading

The recommended install uses `event = "VeryLazy"` for simplicity. If you want the plugin to load ONLY when you first open a markdown file (saving ~10-20ms on startup), use `ft = "markdown"` instead:

```lua
{
  "jeryldev/obsidian-cli.nvim",
  ft = "markdown",
  opts = {},
}
```

**Trade-off:** commands like `:ObsidianToday` won't work until you've opened at least one markdown file. Once the first markdown file loads, all 44 commands and keymaps become available.

For even stricter control (plugin loads ONLY when you invoke a specific command), list the commands you use in `cmd =`:

```lua
{
  "jeryldev/obsidian-cli.nvim",
  cmd = { "ObsidianToday", "ObsidianFind", "ObsidianSearch" },
  opts = {},
}
```

## Disabling default keymaps

If `<leader>o*` conflicts with your existing bindings:

```lua
require("obsidian-cli").setup({
  keymaps = false,
})

-- Then wire your own with whatever prefix you want:
vim.keymap.set("n", "<leader>nt", "<cmd>ObsidianToday<cr>")
vim.keymap.set("n", "<leader>nf", "<cmd>ObsidianFind<cr>")
vim.keymap.set("n", "<leader>ns", "<cmd>ObsidianSearch<cr>")
-- ... etc
```

See [docs/commands.md](commands.md) for the full list of `:Obsidian*` commands.
