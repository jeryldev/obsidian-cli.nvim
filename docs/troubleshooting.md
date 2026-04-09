# Troubleshooting

Common issues, their causes, and how to fix them. Run `:checkhealth obsidian-cli` first when something breaks — it diagnoses most issues automatically.

## "Vault not found"

**Symptom:** any `:Obsidian*` command errors with `Vault not found.`

**Cause:** the Obsidian app is running but no vault is loaded. Either the app started without restoring the previous vault, or it's showing the vault picker.

**Fix:**
1. Click the Obsidian app icon in your Dock
2. Click your vault name to load it
3. In Obsidian: `Settings → About → Open previous vaults on startup` (enable it so this doesn't happen again)
4. Retry the Neovim command

## "The CLI is unable to find Obsidian"

**Symptom:** any `:Obsidian*` command errors with `The CLI is unable to find Obsidian. Please make sure Obsidian is running and try again.`

**Cause:** the Obsidian desktop app is not running. The Obsidian CLI is a remote control client — it requires the desktop app to be live and listening for IPC. There is no headless mode.

**Fix (immediate):**
- **From Neovim:** `:ObsidianStart` (runs the appropriate launcher for your OS)
- **From terminal:** `open -a Obsidian` (macOS) / `obsidian` (Linux) / launch via Start menu (Windows)
- Wait 1-3 seconds for the app to fully boot, then retry your command

**Fix (permanent — recommended):** add Obsidian to your OS startup items so it's always running in the background. After this one-time setup, you'll never see this error again.

- **macOS:** `System Settings → General → Login Items & Extensions → Open at Login → +` → select `Obsidian.app`. Check the "Hide" box to launch invisibly.
- **Linux:** depends on your desktop environment — typically `Settings → Startup Applications → Add` with command `obsidian`
- **Windows:** `Settings → Apps → Startup → Obsidian → On`

Also enable Obsidian's own setting `Settings → About → Open previous vaults on startup` so the app boots into your vault directly instead of showing the vault picker.

**Reference:** the Obsidian CLI's dependence on the running desktop app is documented in the [official Obsidian CLI documentation](https://help.obsidian.md/cli).

## `obsidian` binary not found on PATH

**Symptom:** `:checkhealth obsidian-cli` reports `binary "obsidian" not found on PATH`.

**Cause:** the Obsidian CLI isn't registered with your shell, or the registration happened in a shell session you haven't restarted yet.

**Fix:**
1. In Obsidian: `Settings → General → Command line interface → Register` (or "Install CLI")
2. Restart your terminal so the PATH update takes effect
3. Verify in terminal: `which obsidian` should print a path
4. Re-run `:checkhealth obsidian-cli`

## Squiggly underlines in vault markdown files

**Symptom:** words like `welcome`, `testing`, `file` show squiggly underlines in vault notes.

**Cause:** Vim's built-in spell-check is flagging them as misspelled. The Vim spell dictionary isn't loaded, so even common words get flagged.

**Fix (recommended — turn off spell in vault):** the v0.0.3+ default has `spell = false` in `buffer_options`. If you upgraded from an older version, your old config may have spell on. Check:

```lua
require("obsidian-cli").setup({
  buffer_options = {
    -- ...
    spell = false,  -- this should be false
  },
})
```

**Fix (if you want spell-check):** install a dictionary and set the language:

```lua
require("obsidian-cli").setup({
  buffer_options = {
    spell = true,
    spelllang = "en_us",  -- or your language
  },
})
```

Then run `:set spell` once and Neovim will prompt to download the dictionary if it's missing.

## Markdownlint warnings (MD041, MD012, etc.) in vault files

**Symptom:** vault markdown files show warnings like `MD041/first-line-heading` or `MD012/no-multiple-blanks`.

**Cause:** `markdownlint-cli2` (or similar) is installed via your LSP/none-ls/efm config and runs on every markdown file.

**Fix:** the v0.0.3+ default disables `vim.diagnostic` rendering in vault buffers via `disable_diagnostics_in_vault = true`. If you still see warnings:

1. Verify it's enabled in your config (default is `true`):
   ```lua
   require("obsidian-cli").setup({
     disable_diagnostics_in_vault = true,
   })
   ```

2. Check the disable actually fired for the current buffer:
   ```
   :lua print(vim.diagnostic.is_enabled({ bufnr = 0 }))
   ```
   Should print `false` in vault buffers.

3. If it prints `true`, the buffer was opened before the autocmd registered. Manually re-trigger:
   ```
   :doautocmd FileType markdown
   ```

4. If you want diagnostics back (some users prefer them), set `disable_diagnostics_in_vault = false`.

## Markdown headings appear as raw `##` text instead of styled

**Symptom:** `## sample` shows literal characters instead of a rendered heading.

**Causes & fixes:**

1. **You're in insert mode.** `render-markdown.nvim` (LazyVim's markdown renderer) only renders in normal/cmdline/terminal modes by default. Press `<Esc>` to see the rendering. If you want rendering while typing too, add `"i"` to its `render_modes`:
   ```lua
   {
     "MeanderingProgrammer/render-markdown.nvim",
     opts = {
       render_modes = { "n", "c", "t", "i" },
     },
   }
   ```

2. **The markdown syntax is invalid.** Headings require a space between the `#` markers and the text: `## sample`, NOT `##sample`. Without the space, it's treated as a paragraph.

3. **render-markdown isn't installed.** Check `:Lazy` for `render-markdown.nvim`. If missing, you may need to enable LazyVim's `lang.markdown` extra or install it explicitly.

## Picker preview shows raw markdown (`##` instead of styled headings)

**This is a known v0.0.3 limitation, not a bug.** The Snacks preview pane shows markdown files with treesitter syntax highlighting (code blocks colored, bold/italic minimally styled) but does NOT render headings, links, or extmark-based styling the way `render-markdown.nvim` does in normal buffers.

**Why:** Snacks's preview is a transient scratch buffer (`buftype = nofile`) that gets recreated on each selection change. Extmark-based renderers like render-markdown need a stable buffer + window pair with persistent treesitter parsing — the two architectures don't currently mesh cleanly.

**Workaround:** to see a fully-rendered view of a note, select it from the picker (Enter) to open it in your main buffer. render-markdown will activate normally in the regular buffer.

**Tracked for v0.1.0** as a polish item.

## Picker preview shows `(empty file)` for actually-empty files

**This is intentional and correct.** The custom Snacks previewer shows `(empty file)` for zero-byte files instead of falling into Snacks's debug-dump fallback. If you see content for non-empty files and the empty message for empty ones, it's working as designed.

## Picker preview shows the wrong file

**Symptom:** previewing item A shows the content of item B.

**Cause:** picker items have the wrong `file` field. This shouldn't happen in v0.0.3+, but if you see it, file an issue with the exact picker (`:ObsidianFind`, `:ObsidianSearch`, etc.) and the items shown.

## `:ObsidianTasksToday` shows tasks from other files

**Symptom:** the picker for today's tasks includes `[x] sample` from `sample.md` (not today's note).

**Cause:** this shouldn't happen in v0.0.3+ — the wrapper filters by today's daily note via `obsidian tasks daily`. If you still see it:

1. Run `obsidian tasks daily format=json` in your terminal — confirm whether the CLI is returning tasks from other files. If yes, the CLI's `daily` filter is broken (file an issue at `obsidian-cli` upstream).
2. As a workaround, the wrapper could filter Lua-side by comparing each entry's `file` against `obsidian daily:path`. If you hit this, file an issue and we'll add the workaround.

## Wiki link completion popup is empty when typing `[[`

**Symptom:** typing `[[` in a vault markdown file produces no popup.

**Cause:** one of three things:
1. The blink.cmp source isn't registered
2. The plugin's `enabled()` callback returns false (vault not detected)
3. blink.cmp itself isn't loaded

**Fix:** see [docs/completion.md → Troubleshooting](completion.md#troubleshooting).

## Multiple `[[` brackets appearing after completion

**Symptom:** accepting a completion produces `[[Welcome]]]]` with extra closing brackets.

**Cause:** old auto-pairs interop bug from v0.0.2 or earlier.

**Fix:** upgrade to v0.0.3 or later. The textEdit range now consumes existing `]]` characters automatically regardless of whether auto-pairs is active.

## Plugin doesn't load — `module 'obsidian-cli' not found`

**Causes:**
1. The plugin wasn't registered with Lazy.nvim
2. Lazy.nvim cached an old plugin tree
3. The local `dir =` path is wrong

**Fix:**
1. Verify the spec exists: `:Lazy` should list `obsidian-cli.nvim`
2. If installed via local `dir`, verify the path: `:lua print(vim.fn.isdirectory(vim.fn.expand("~/code/obsidian-cli.nvim")))` should print `1`
3. Force a Lazy reload: `:Lazy reload obsidian-cli.nvim`
4. If that fails, restart Neovim (some Lazy state requires a fresh boot)
5. Check `:lua print(vim.api.nvim_get_runtime_file("lua/obsidian-cli/init.lua", false)[1])` — should print the absolute path to the plugin's init.lua

## Diagnostics returned `nil` when probing

**Symptom:** `:lua print(vim.diagnostic.is_enabled({ bufnr = 0 }))` prints `nil`.

**Cause:** Neovim version older than 0.10. The `vim.diagnostic.is_enabled` API was added in 0.10. The plugin requires Neovim 0.10+.

**Fix:** upgrade Neovim. `brew upgrade neovim` on macOS, or your platform's equivalent.

## Plugin commands work but feel slow

**Symptom:** `:ObsidianFind` etc. take a noticeable second or more to open.

**Causes:**
1. **Cold-start CLI invocation** — first command in a session pays a one-time ~50-100ms cost
2. **Large vault** — vaults with 5000+ markdown files take longer for `obsidian files` to enumerate
3. **Search command parsing** — `obsidian search:context format=json` on big vaults can take 200-500ms

**Mitigations:**
- The first command is unavoidable. Subsequent commands hit cached state and are fast.
- For large vaults, consider creating a search index or using `:ObsidianRecent` for hot files.
- If the CLI itself feels slow, verify the Obsidian app isn't doing background sync — check Obsidian's status bar.

## Found a bug not listed here?

File an issue at [github.com/jeryldev/obsidian-cli.nvim/issues](https://github.com/jeryldev/obsidian-cli.nvim/issues) with:

1. Output of `:checkhealth obsidian-cli`
2. The exact command that failed
3. Any error message
4. Your `obsidian version` output
5. Your `nvim --version` output
