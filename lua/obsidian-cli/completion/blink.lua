-- blink.cmp source for vault-aware [[wiki link]] completion.
--
-- Register in your blink.cmp config:
--
--   sources = {
--     default = { "lsp", "path", "snippets", "buffer", "obsidian" },
--     providers = {
--       obsidian = {
--         name = "Obsidian",
--         module = "obsidian-cli.completion.blink",
--         score_offset = 100,
--       },
--     },
--   }

local cli = require("obsidian-cli.cli")
local util = require("obsidian-cli.util")

local CompletionItemKind = vim.lsp.protocol.CompletionItemKind

local source = {}
source.__index = source

function source.new(opts)
  return setmetatable({ opts = opts or {} }, source)
end

function source:get_trigger_characters()
  return { "[" }
end

local function in_wiki_context()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local before = line:sub(1, col)
  -- Match `[[<query>` where <query> contains no closing ]]
  local query = before:match("%[%[([^%[%]]*)$")
  if not query then
    return nil
  end
  return query, col - #query
end

function source:enabled()
  local plugin_ok, plugin = pcall(require, "obsidian-cli")
  if not plugin_ok or not plugin.config then
    return false
  end
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    return false
  end
  local vp = cli.vault_path()
  if not vp then
    return false
  end
  return util.in_vault(path, vp)
end

local cache = { files = nil, expires = 0 }
local TTL_MS = 2000

local function get_vault_files()
  local now = (vim.uv or vim.loop).now()
  if cache.files and now < cache.expires then
    return cache.files
  end
  local out, err = cli.run({ "files", "ext=md" })
  if err then
    return cache.files or {}
  end
  cache.files = util.split_lines(out)
  cache.expires = now + TTL_MS
  return cache.files
end

-- If auto-pairs inserted `]]` immediately after the cursor, extend the
-- replacement range to consume those characters so we end up with exactly
-- `[[name]]` regardless of whether auto-pairs is active.
local function trailing_close_offset()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local after = line:sub(col + 1)
  if after:sub(1, 2) == "]]" then
    return 2
  end
  if after:sub(1, 1) == "]" then
    return 1
  end
  return 0
end

function source:get_completions(ctx, callback)
  local _, query_start = in_wiki_context()
  if not query_start then
    callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
    return
  end

  local files = get_vault_files()
  local lnum = ctx.cursor[1] - 1
  local cursor_col = ctx.cursor[2]
  local end_col = cursor_col + trailing_close_offset()

  local items = {}
  for _, rel in ipairs(files) do
    local link = rel:gsub("%.md$", "")
    local basename = link:match("([^/]+)$") or link
    table.insert(items, {
      label = link,
      filterText = link,
      kind = CompletionItemKind.File,
      detail = basename ~= link and basename or nil,
      insertText = link .. "]]",
      textEdit = {
        newText = link .. "]]",
        range = {
          start = { line = lnum, character = query_start },
          ["end"] = { line = lnum, character = end_col },
        },
      },
    })
  end

  callback({
    items = items,
    is_incomplete_backward = false,
    is_incomplete_forward = false,
  })
end

return source
