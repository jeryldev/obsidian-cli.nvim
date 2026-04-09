local M = {}

local config

local function detect()
  if pcall(require, "snacks") then
    return "snacks"
  end
  return "quickfix"
end

local function backend()
  local picked = (config and config.picker) or detect()
  return picked
end

function M.setup(c)
  config = c
end

function M.pick(items, opts)
  local kind = backend()
  if kind == "snacks" then
    local ok = require("obsidian-cli.pickers.snacks").files(items, opts)
    if ok then
      return
    end
  end
  require("obsidian-cli.pickers.quickfix").files(items, opts)
end

-- Selection helper for non-file items (command IDs, plugin names, etc.).
-- Prefers Snacks's native picker (bypassing the broken vim.ui.select
-- override). Falls back through vim.ui.select in a pcall for non-Snacks
-- users, and ultimately to vim.fn.inputlist if all else fails.
--
-- Args:
--   items      — array of items to select from
--   opts       — { prompt, format_item } same shape as vim.ui.select
--   on_choice  — function(item) called with nil if cancelled
function M.select(items, opts, on_choice)
  opts = opts or {}
  if type(items) ~= "table" or #items == 0 then
    on_choice(nil)
    return
  end

  -- Preferred path: call our Snacks adapter directly with a non-file
  -- picker layout. Avoids the broken vim.ui.select override entirely.
  local kind = backend()
  if kind == "snacks" then
    local ok, success = pcall(require("obsidian-cli.pickers.snacks").select, items, opts, on_choice)
    if ok and success then
      return
    end
  end

  -- Second choice: generic vim.ui.select with pcall guard. This still
  -- routes through Snacks's ui.select override if Snacks is active, so
  -- it may crash — but it's wrapped in pcall to catch that.
  local ok_ui = pcall(vim.ui.select, items, opts, function(choice)
    on_choice(choice)
  end)
  if ok_ui then
    return
  end

  -- Last resort: Vim's built-in numbered list. Ugly but bulletproof.
  local prompt = opts.prompt or "Select:"
  local lines = { prompt }
  for i, item in ipairs(items) do
    local label = opts.format_item and opts.format_item(item) or tostring(item)
    table.insert(lines, string.format("%d. %s", i, label))
  end
  local choice_idx = vim.fn.inputlist(lines)
  if choice_idx > 0 and choice_idx <= #items then
    on_choice(items[choice_idx])
  else
    on_choice(nil)
  end
end

-- Live search picker — re-queries on each keystroke. Snacks only for v0.0.3;
-- quickfix fallback doesn't support live search, so falls back to a one-shot
-- search over the initial empty pattern (effectively a no-op).
function M.live_search(opts)
  local kind = backend()
  if kind == "snacks" then
    local ok = require("obsidian-cli.pickers.snacks").live_search(opts)
    if ok then
      return
    end
  end
  vim.notify(
    "obsidian-cli: live search requires snacks.nvim — use `:ObsidianSearch <query>` for one-shot search",
    vim.log.levels.WARN
  )
end

return M
