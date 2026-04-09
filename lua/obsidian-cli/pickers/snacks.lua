local M = {}

local function snacks_ok()
  local ok, snacks = pcall(require, "snacks")
  return ok and snacks or nil
end

-- Custom previewer that shows file content for non-empty files,
-- and a clean placeholder message for empty ones (instead of Snacks's
-- default debug dump).
local function file_preview(ctx)
  local item = ctx.item
  if not item or not item.file or item.file == "" then
    ctx.preview:set_lines({ "(no file)" })
    return
  end

  local stat = (vim.uv or vim.loop).fs_stat(item.file)
  if not stat then
    ctx.preview:set_lines({ "(file not found: " .. item.file .. ")" })
    return
  end

  if stat.type ~= "file" then
    ctx.preview:set_lines({ "(not a regular file: " .. stat.type .. ")" })
    return
  end

  if stat.size == 0 then
    ctx.preview:set_lines({ "", "  (empty file)", "" })
    return
  end

  local ok, lines = pcall(vim.fn.readfile, item.file)
  if not ok or type(lines) ~= "table" then
    ctx.preview:set_lines({ "(unable to read file)" })
    return
  end
  ctx.preview:set_lines(lines)

  -- Apply syntax highlighting based on file extension.
  local ext = item.file:match("%.([%w]+)$")
  local ft = ext == "md" and "markdown" or (ext == "canvas" and "json" or nil)
  if ft and ctx.preview.buf then
    pcall(vim.api.nvim_set_option_value, "filetype", ft, { buf = ctx.preview.buf })

    -- Note: render-markdown.nvim integration in the preview pane is a known
    -- v0.0.3 limitation. Snacks's preview is a transient `nofile` scratch
    -- buffer that doesn't currently mesh with extmark-based renderers like
    -- render-markdown. The preview gets treesitter syntax highlighting from
    -- the filetype above (code blocks colored, bold/italic minimal styling),
    -- but headings appear as raw `## text` rather than rendered headings.
    -- Tracked as a v0.1.0 polish item.
  end

  -- If the item has a line number (e.g. search results, backlinks),
  -- jump the preview window to it.
  if item.pos and item.pos[1] and ctx.preview.win then
    pcall(vim.api.nvim_win_set_cursor, ctx.preview.win, { item.pos[1], 0 })
  end
end

-- Non-file selection picker. Used for choosing command IDs, plugin
-- names, and other non-file items. Bypasses `vim.ui.select` because
-- Snacks's override of it occasionally crashes with a fractional-height
-- error on certain item counts — we call snacks.picker.pick directly
-- with a custom format function instead.
function M.select(items, opts, on_choice)
  local snacks = snacks_ok()
  if not snacks or not snacks.picker then
    return false
  end
  opts = opts or {}
  local snacks_items = {}
  for i, item in ipairs(items) do
    local label = opts.format_item and opts.format_item(item) or tostring(item)
    table.insert(snacks_items, {
      idx = i,
      text = label,
      _value = item,
    })
  end
  snacks.picker.pick({
    source = "obsidian-cli-select",
    title = opts.prompt or "Select",
    items = snacks_items,
    format = function(item)
      return { { item.text } }
    end,
    -- These items are command IDs / plugin names, not file paths.
    -- Disable the preview (which defaults to a file previewer) so Snacks
    -- doesn't try to stat a non-existent file.
    preview = "none",
    layout = { preview = false },
    confirm = function(picker, item)
      picker:close()
      if item and item._value then
        on_choice(item._value)
      else
        on_choice(nil)
      end
    end,
  })
  return true
end

-- Shared confirm handler for both static (M.files) and live (M.live_search)
-- pickers. Opens the selected file in the current buffer, positions the
-- cursor at `item.pos` if set, or searches for `item.search` text in the
-- newly-opened buffer and lands inside the matched span.
local function confirm_open(picker, item)
  picker:close()
  if not item or not item.file then
    return
  end
  vim.cmd.edit(vim.fn.fnameescape(item.file))
  if item.pos then
    pcall(vim.api.nvim_win_set_cursor, 0, item.pos)
    return
  end
  if item.search and item.search ~= "" then
    local pattern = vim.fn.escape(item.search, "\\/.*$^~[]")
    local ok, found = pcall(vim.fn.search, pattern, "w")
    if ok and found and found > 0 then
      pcall(vim.cmd, "normal! 2l")
    end
  end
end

-- Live search: finder callback runs on every keystroke (debounced by Snacks).
-- Snacks finder signature is `function(picker_opts, ctx)` where the current
-- search pattern lives at `ctx.filter.search`. The finder returns a flat
-- array of picker items.
function M.live_search(opts)
  local snacks = snacks_ok()
  if not snacks or not snacks.picker then
    return false
  end
  opts = opts or {}
  snacks.picker.pick({
    source = "obsidian-cli-search",
    title = opts.title or "obsidian-cli: search",
    live = true,
    supports_live = true,
    format = "file",
    preview = file_preview,
    finder = function(_, ctx)
      local pattern = ctx and ctx.filter and ctx.filter.search or ""
      if pattern == "" then
        return {}
      end
      local ok_fetch, items = pcall(opts.fetch, pattern)
      if not ok_fetch or type(items) ~= "table" then
        return {}
      end
      local result = {}
      for i, item in ipairs(items) do
        table.insert(result, {
          idx = i,
          file = item.path,
          text = item.display or item.text or item.path,
          pos = item.lnum and { item.lnum, 0 } or nil,
        })
      end
      return result
    end,
    confirm = confirm_open,
  })
  return true
end

function M.files(items, opts)
  local snacks = snacks_ok()
  if not snacks or not snacks.picker then
    return false
  end
  opts = opts or {}
  local snacks_items = {}
  for i, item in ipairs(items) do
    table.insert(snacks_items, {
      idx = i,
      file = item.path,
      text = item.display or item.text or item.path,
      pos = item.lnum and { item.lnum, 0 } or nil,
      search = item.search,
    })
  end
  snacks.picker.pick({
    source = "obsidian-cli",
    title = opts.title or "obsidian-cli",
    items = snacks_items,
    format = "file",
    preview = file_preview,
    confirm = confirm_open,
  })
  return true
end

return M
