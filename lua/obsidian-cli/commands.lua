local M = {}

local cli = require("obsidian-cli.cli")
local util = require("obsidian-cli.util")
local pickers = require("obsidian-cli.pickers")

local function friendly_error(err)
  err = tostring(err or "")
  if err:match("Vault not found") then
    return err .. "\nHint: open a vault in the Obsidian app, or set `vault` in setup() to target a specific one."
  end
  if err:match("unable to find Obsidian") then
    return err .. "\nHint: launch the Obsidian desktop app (e.g. `open -a Obsidian`) and retry."
  end
  return err
end

-- Confirm a destructive action with a Yes/No prompt. Returns true if the
-- user confirmed (chose Yes), false otherwise. Default button is No so
-- accidental Enter presses do not destroy state.
--
-- Example:
--   if not confirm_destructive("Delete `foo.md`?") then return end
local function confirm_destructive(prompt)
  local choice = vim.fn.confirm(prompt, "&Yes\n&No", 2)
  return choice == 1
end

local function notify_error(name, err)
  vim.notify(name .. ": " .. friendly_error(err), vim.log.levels.ERROR)
end

local function notify_info(msg)
  vim.notify(msg, vim.log.levels.INFO)
end

local function vault_path_or_error(name)
  local vp, err = cli.vault_path()
  if not vp then
    notify_error(name, err or "could not resolve vault path")
    return nil
  end
  return vp
end

local function open_relative(name, relpath)
  local vp = vault_path_or_error(name)
  if not vp then
    return
  end
  local abs = util.absolute(vim.trim(relpath), vp)
  if not abs then
    notify_error(name, "no path returned")
    return
  end
  vim.cmd.edit(vim.fn.fnameescape(abs))
end

-- Returns the buffer handle for today's note if it is currently loaded,
-- otherwise nil. Used to prefer in-buffer edits over disk writes for
-- instant visual feedback.
local function find_today_buffer()
  local out, err = cli.run({ "daily:path" })
  if err then
    return nil
  end
  local rel = vim.trim(out)
  if rel == "" then
    return nil
  end
  local vp = cli.vault_path()
  if not vp then
    return nil
  end
  local abs = util.absolute(rel, vp)
  if not abs then
    return nil
  end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name == abs then
        return bufnr
      end
    end
  end
  return nil
end

local function cmd_today()
  -- Prefer switching to today's note if it's already loaded in a buffer.
  -- Falls back to :edit for the resolved absolute path.
  local buf = find_today_buffer()
  if buf then
    vim.api.nvim_set_current_buf(buf)
    return
  end
  local out, err = cli.run({ "daily:path" })
  if err then
    notify_error("ObsidianToday", err)
    return
  end
  open_relative("ObsidianToday", out)
end

local function append_daily(name, content)
  if not content or content == "" then
    notify_error(name, "content required")
    return
  end

  -- If today's note is already open in a buffer, append in-place so the
  -- change is instantly visible. Otherwise fall back to the CLI which
  -- writes to disk directly.
  local buf = find_today_buffer()
  if buf then
    local line_count = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, { content })
    -- If today's note is the current buffer, move the cursor to the
    -- newly-appended line. Skip this when it's in a background buffer
    -- to avoid jerking the user around.
    if buf == vim.api.nvim_get_current_buf() then
      pcall(vim.api.nvim_win_set_cursor, 0, { line_count + 1, #content })
    end
    return
  end

  local _, err = cli.run({ "daily:append", "content=" .. content })
  if err then
    notify_error(name, err)
    return
  end
  notify_info(name .. ": appended")
end

local function cmd_task(opts)
  append_daily("ObsidianTask", "- [ ] " .. opts.args)
end

local function cmd_todo(opts)
  append_daily("ObsidianTodo", "- [ ] " .. opts.args)
end

local function cmd_append(opts)
  append_daily("ObsidianAppend", opts.args)
end

-- The CLI's `tasks daily todo` filter combo returns "No tasks found." even
-- when tasks exist. Use `tasks daily` and filter to incomplete tasks in Lua
-- (status == " " means an unchecked checkbox).
local function cmd_tasks_today()
  local data, err = cli.run_json({ "tasks", "daily", "format=json" })
  if err then
    notify_error("ObsidianTasksToday", err)
    return
  end
  local vp = vault_path_or_error("ObsidianTasksToday")
  if not vp then
    return
  end
  local items = {}
  if type(data) == "table" then
    for _, entry in ipairs(data) do
      if (entry.status or " ") == " " then
        local rel = entry.file or entry.path or ""
        local abs = util.absolute(rel, vp) or rel
        table.insert(items, {
          path = abs,
          lnum = tonumber(entry.line or entry.lnum) or 1,
          text = entry.text or entry.task or rel,
        })
      end
    end
  end
  pickers.pick(items, { title = "Obsidian: today's tasks" })
end

local function open_new_note(name, title)
  local vp = vault_path_or_error(name)
  if not vp then
    return
  end
  local fname = title
  if not fname:lower():match("%.md$") then
    fname = fname .. ".md"
  end
  local abs = util.absolute(fname, vp)
  if abs and vim.fn.filereadable(abs) == 1 then
    vim.cmd.edit(vim.fn.fnameescape(abs))
  else
    -- Created in a non-default folder or with a different name; fall back to picker.
    notify_info(name .. ": created `" .. title .. "` (use :ObsidianFind to open)")
  end
end

local function cmd_new(opts)
  local title = opts.args
  if title == "" then
    notify_error("ObsidianNew", "title required")
    return
  end
  local _, err = cli.run({ "create", "name=" .. title })
  if err then
    notify_error("ObsidianNew", err)
    return
  end
  notify_info("Created: " .. title)
  open_new_note("ObsidianNew", title)
end

local function cmd_new_from(opts)
  local args = vim.split(opts.args, "%s+", { trimempty = true })
  if #args < 2 then
    notify_error("ObsidianNewFrom", "usage: :ObsidianNewFrom <template> <title>")
    return
  end
  local template = table.remove(args, 1)
  local title = table.concat(args, " ")
  local _, err = cli.run({ "create", "name=" .. title, "template=" .. template })
  if err then
    notify_error("ObsidianNewFrom", err)
    return
  end
  notify_info("Created from " .. template .. ": " .. title)
  open_new_note("ObsidianNewFrom", title)
end

local function list_files()
  local out, err = cli.run({ "files" })
  if err then
    return nil, err
  end
  return util.split_lines(out), nil
end

local function cmd_find()
  local files, err = list_files()
  if err then
    notify_error("ObsidianFind", err)
    return
  end
  local vp = vault_path_or_error("ObsidianFind")
  if not vp then
    return
  end
  local items = {}
  for _, rel in ipairs(files) do
    table.insert(items, { path = util.absolute(rel, vp) or rel, display = rel })
  end
  pickers.pick(items, { title = "Obsidian: find" })
end

local function cmd_recent()
  local files, err = list_files()
  if err then
    notify_error("ObsidianRecent", err)
    return
  end
  local vp = vault_path_or_error("ObsidianRecent")
  if not vp then
    return
  end
  local stamped = {}
  for _, rel in ipairs(files) do
    local abs = util.absolute(rel, vp) or rel
    local mtime = vim.uv and vim.uv.fs_stat(abs)
    table.insert(stamped, {
      path = abs,
      display = rel,
      mtime = (mtime and mtime.mtime and mtime.mtime.sec) or 0,
    })
  end
  table.sort(stamped, function(a, b)
    return a.mtime > b.mtime
  end)
  local plugin_config = require("obsidian-cli").config or {}
  local limit = plugin_config.recent_limit or 20
  local items = {}
  for i = 1, math.min(limit, #stamped) do
    table.insert(items, stamped[i])
  end
  pickers.pick(items, { title = "Obsidian: recent" })
end

-- Fetch search results as a flat picker item list for a given query.
-- Shared by both the one-shot and live-search variants of :ObsidianSearch.
local function fetch_search_items(query)
  local data, err = cli.run_json({ "search:context", "query=" .. query, "format=json" })
  if err or type(data) ~= "table" then
    return {}
  end
  local vp = cli.vault_path() or ""
  local items = {}
  for _, entry in ipairs(data) do
    local rel = entry.file or ""
    local abs = util.absolute(rel, vp) or rel
    local matches = entry.matches or {}
    if #matches == 0 then
      table.insert(items, { path = abs, display = rel, lnum = 1, text = rel })
    else
      for _, m in ipairs(matches) do
        table.insert(items, {
          path = abs,
          display = rel,
          lnum = tonumber(m.line) or 1,
          text = m.text or "",
        })
      end
    end
  end
  return items
end

local function cmd_search(opts)
  local query = opts.args
  if query == "" then
    -- Live search mode — picker opens immediately, results update as you type.
    pickers.live_search({
      title = "Obsidian: search",
      fetch = fetch_search_items,
    })
    return
  end
  -- One-shot mode — query passed as command arg, static result list.
  pickers.pick(fetch_search_items(query), { title = "Obsidian: search — " .. query })
end

local function cmd_backlinks()
  local current = vim.api.nvim_buf_get_name(0)
  if current == "" then
    notify_error("ObsidianBacklinks", "no current file")
    return
  end
  local vp = vault_path_or_error("ObsidianBacklinks")
  if not vp then
    return
  end
  local rel = util.relative_to_vault(current, vp)
  local data, err = cli.run_json({ "backlinks", "path=" .. rel, "format=json" })
  if err then
    notify_error("ObsidianBacklinks", err)
    return
  end
  local items = {}
  if type(data) == "table" then
    for _, entry in ipairs(data) do
      if type(entry) == "string" then
        table.insert(items, { path = util.absolute(entry, vp) or entry, display = entry })
      elseif type(entry) == "table" then
        local f = entry.file or entry.path or ""
        table.insert(items, {
          path = util.absolute(f, vp) or f,
          display = f,
          lnum = tonumber(entry.line) or 1,
          text = entry.text or f,
        })
      end
    end
  end
  pickers.pick(items, { title = "Obsidian: backlinks" })
end

-- Toggle the markdown task checkbox on the current line, in-place via the
-- buffer API. Avoids the round-trip through the CLI + file watcher, which
-- caused real-time-update problems.
local function cmd_task_toggle()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1]
  if not line then
    notify_error("ObsidianTaskToggle", "empty buffer")
    return
  end

  local new_line, replaced
  if line:match("%[%s%]") then
    new_line, replaced = line:gsub("%[%s%]", "[x]", 1)
  elseif line:match("%[[xX]%]") then
    new_line, replaced = line:gsub("%[[xX]%]", "[ ]", 1)
  end

  if not replaced or replaced == 0 then
    notify_error("ObsidianTaskToggle", "no checkbox on this line")
    return
  end

  vim.api.nvim_buf_set_lines(0, lnum - 1, lnum, false, { new_line })
end

-- Create a new note from the [[wiki link]] under the cursor. Useful for
-- resolving broken links surfaced by :ObsidianUnresolved — jump to the
-- source file, cursor lands on the broken link, press <leader>oR to
-- create the target note.
local function cmd_resolve_link()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-indexed

  -- Find the [[...]] span that contains the cursor column.
  local target
  local search_from = 1
  while true do
    local s, e = line:find("%[%[[^%[%]]+%]%]", search_from)
    if not s then
      break
    end
    if col >= s and col <= e then
      target = line:sub(s + 2, e - 2)
      break
    end
    search_from = e + 1
  end

  if not target or target == "" then
    notify_error("ObsidianResolveLink", "no [[wiki link]] under cursor")
    return
  end

  -- Strip alias syntax: [[Name|Display Text]] -> "Name"
  target = target:match("^([^|]+)") or target
  -- Strip heading/block reference: [[Name#Heading]] -> "Name"
  target = target:match("^([^#]+)") or target
  target = vim.trim(target)

  if target == "" then
    notify_error("ObsidianResolveLink", "empty link name")
    return
  end

  local _, err = cli.run({ "create", "name=" .. target })
  if err then
    notify_error("ObsidianResolveLink", err)
    return
  end
  notify_info("Created: " .. target .. " (the link now resolves)")
  open_new_note("ObsidianResolveLink", target)
end

-- Extract the [[wiki link]] span that contains the cursor column.
-- Returns the raw inner text (e.g. "Note Name" or "Note|Alias" or
-- "Note#Heading") or nil if the cursor isn't inside a link.
local function wiki_link_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-indexed
  local search_from = 1
  while true do
    local s, e = line:find("%[%[[^%[%]]+%]%]", search_from)
    if not s then
      return nil
    end
    if col >= s and col <= e then
      return line:sub(s + 2, e - 2)
    end
    search_from = e + 1
  end
end

-- Normalize a raw link inner text to a bare note name. Strips alias
-- suffix (`|Display`), heading reference (`#Heading`), and block
-- reference (`^block-id`). Returns the cleaned name or nil if empty.
local function normalize_link_target(raw)
  if not raw or raw == "" then
    return nil
  end
  local t = raw
  t = t:match("^([^|]+)") or t -- strip alias
  t = t:match("^([^#]+)") or t -- strip heading
  t = t:match("^([^%^]+)") or t -- strip block ref
  t = vim.trim(t)
  if t == "" then
    return nil
  end
  return t
end

-- Find a vault file that matches a link target. Returns the
-- vault-relative path if found, nil otherwise. Matches in priority order:
--   1. Exact vault-relative path (with or without .md extension)
--   2. Basename match (supports `[[Note]]` → `folder/Note.md`)
-- The match is case-insensitive to mirror Obsidian's resolver.
local function find_file_for_link(target, files)
  local wanted_path = target:lower()
  if not wanted_path:match("%.md$") then
    wanted_path = wanted_path .. ".md"
  end
  local wanted_basename = wanted_path:match("([^/]+)$")

  -- Pass 1: exact vault-relative path match
  for _, rel in ipairs(files) do
    if rel:lower() == wanted_path then
      return rel
    end
  end
  -- Pass 2: basename match
  for _, rel in ipairs(files) do
    local rel_base = rel:match("([^/]+)$") or rel
    if rel_base:lower() == wanted_basename then
      return rel
    end
  end
  return nil
end

-- Follow the [[wiki link]] under the cursor. If the target note exists,
-- opens it in the current buffer. If it doesn't exist, prompts to create.
-- This is the "smart gf" for wiki links — equivalent to clicking a link
-- in Obsidian's UI.
local function cmd_follow_link()
  local raw = wiki_link_under_cursor()
  if not raw then
    notify_error("ObsidianFollowLink", "no [[wiki link]] under cursor")
    return
  end
  local target = normalize_link_target(raw)
  if not target then
    notify_error("ObsidianFollowLink", "empty link name")
    return
  end
  local vp = vault_path_or_error("ObsidianFollowLink")
  if not vp then
    return
  end
  local files, err = list_files()
  if err then
    notify_error("ObsidianFollowLink", err)
    return
  end
  local match = find_file_for_link(target, files)
  if match then
    local abs = util.absolute(match, vp) or match
    vim.cmd.edit(vim.fn.fnameescape(abs))
    return
  end
  -- File doesn't exist — offer to create it. Use default-Yes because the
  -- user explicitly pressed "follow link", so create is the expected path.
  local choice = vim.fn.confirm(
    "Note `" .. target .. "` doesn't exist in the vault.\nCreate it?",
    "&Yes\n&No",
    1 -- default to Yes
  )
  if choice ~= 1 then
    notify_info("Cancelled: " .. target)
    return
  end
  local _, create_err = cli.run({ "create", "name=" .. target })
  if create_err then
    notify_error("ObsidianFollowLink", create_err)
    return
  end
  notify_info("Created: " .. target)
  open_new_note("ObsidianFollowLink", target)
end

local function cmd_unresolved()
  local data, err = cli.run_json({ "unresolved", "format=json", "verbose" })
  if err then
    notify_error("ObsidianUnresolved", err)
    return
  end
  local vp = vault_path_or_error("ObsidianUnresolved")
  if not vp then
    return
  end
  local items = {}
  if type(data) == "table" then
    for _, entry in ipairs(data) do
      if type(entry) == "string" then
        table.insert(items, { path = "", display = entry, text = entry })
      elseif type(entry) == "table" then
        local link = entry.link or entry.target or "?"
        local raw_sources = entry.sources or entry.files or entry.source or entry.file
        local source_list = {}
        if type(raw_sources) == "string" and raw_sources ~= "" then
          -- The CLI returns a string, either a single filename or a
          -- comma-separated list if the same link appears in many files.
          for s in raw_sources:gmatch("[^,]+") do
            table.insert(source_list, vim.trim(s))
          end
        elseif type(raw_sources) == "table" then
          for _, s in ipairs(raw_sources) do
            table.insert(source_list, tostring(s))
          end
        end
        if #source_list == 0 then
          table.insert(items, {
            path = "",
            display = "[[" .. link .. "]]",
            text = "[[" .. link .. "]]",
            search = "[[" .. link .. "]]",
          })
        else
          for _, src in ipairs(source_list) do
            table.insert(items, {
              path = util.absolute(src, vp) or src,
              display = src .. "  →  [[" .. link .. "]]",
              text = "[[" .. link .. "]]",
              search = "[[" .. link .. "]]",
            })
          end
        end
      end
    end
  end
  pickers.pick(items, { title = "Obsidian: unresolved links" })
end

-- Execute any registered Obsidian command by ID. Escape hatch that reaches
-- the full Obsidian plugin ecosystem (Templater, Dataview, Tasks, etc.)
-- without needing per-plugin wrappers.
local function cmd_command(opts)
  local id = vim.trim(opts.args or "")
  if id == "" then
    notify_error("ObsidianCommand", "command id required (use :ObsidianCommandList to browse)")
    return
  end
  local _, err = cli.run({ "command", "id=" .. id })
  if err then
    notify_error("ObsidianCommand", err)
    return
  end
  notify_info("Ran: " .. id)
end

-- List all registered Obsidian commands (core + community plugins) and
-- let the user pick one to execute. Accepts an optional filter prefix.
local function cmd_command_list(opts)
  local args = { "commands" }
  local filter = vim.trim(opts.args or "")
  if filter ~= "" then
    table.insert(args, "filter=" .. filter)
  end
  local out, err = cli.run(args)
  if err then
    notify_error("ObsidianCommandList", err)
    return
  end
  local lines = util.split_lines(out)
  if #lines == 0 then
    notify_info("ObsidianCommandList: no commands matched")
    return
  end
  -- Each line looks like `plugin-id:command-id  Display Name` — extract
  -- the id (first whitespace-delimited token) so we can pass it to
  -- `obsidian command id=<id>` when the user picks an entry.
  local items = {}
  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed ~= "" then
      local id = trimmed:match("^(%S+)") or trimmed
      table.insert(items, {
        command_id = id,
        text = trimmed,
        display = trimmed,
      })
    end
  end
  -- Uses pickers.select (which wraps vim.ui.select with a fallback to
  -- vim.fn.inputlist) because entries aren't files — they're command IDs.
  pickers.select(items, {
    prompt = "Obsidian command:",
    format_item = function(item)
      return item.display
    end,
  }, function(choice)
    if not choice then
      return
    end
    local _, exec_err = cli.run({ "command", "id=" .. choice.command_id })
    if exec_err then
      notify_error("ObsidianCommandList", exec_err)
      return
    end
    notify_info("Ran: " .. choice.command_id)
  end)
end

-- ============================================================================
-- Bases — wrap the `obsidian bases`, `base:*` family of commands
-- (Bases is a CORE plugin in Obsidian 1.8+, not a community plugin)
-- ============================================================================

-- Returns true if the plain-text CLI output matches a "No X found." pattern,
-- which the CLI uses for empty results on commands that don't return JSON.
local function is_empty_text_result(text)
  if not text or text == "" then
    return true
  end
  return vim.trim(text):match("^No .* found") ~= nil
end

local function cmd_bases()
  local out, err = cli.run({ "bases" })
  if err then
    notify_error("ObsidianBases", err)
    return
  end
  if is_empty_text_result(out) then
    notify_info("ObsidianBases: no .base files in vault")
    return
  end
  local rel_paths = util.split_lines(out)
  if #rel_paths == 0 then
    notify_info("ObsidianBases: no .base files in vault")
    return
  end
  local vp = vault_path_or_error("ObsidianBases")
  if not vp then
    return
  end
  local items = {}
  for _, rel in ipairs(rel_paths) do
    table.insert(items, {
      path = util.absolute(rel, vp) or rel,
      display = rel,
    })
  end
  pickers.pick(items, { title = "Obsidian: bases" })
end

-- List views in a specific .base file.
local function cmd_base_views(opts)
  local args = { "base:views" }
  local path_arg = vim.trim(opts.args or "")
  if path_arg ~= "" then
    table.insert(args, "path=" .. path_arg)
  end
  local out, err = cli.run(args)
  if err then
    notify_error("ObsidianBaseViews", err)
    return
  end
  local lines = util.split_lines(out)
  if #lines == 0 then
    notify_info("ObsidianBaseViews: no views in this base")
    return
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Obsidian base views" })
end

-- Query a base view and show results. Accepts "<base_path> <view_name>".
-- Result file paths become a picker; non-file results are shown in a notification.
local function cmd_base_query(opts)
  local args = vim.split(vim.trim(opts.args or ""), "%s+", { trimempty = true })
  if #args < 2 then
    notify_error("ObsidianBaseQuery", "usage: :ObsidianBaseQuery <base-path> <view>")
    return
  end
  local base_path = args[1]
  local view = table.concat(args, " ", 2)
  -- Use `format=paths` to get one file per line — cleanest for picker rendering.
  local out, err = cli.run({
    "base:query",
    "path=" .. base_path,
    "view=" .. view,
    "format=paths",
  })
  if err then
    notify_error("ObsidianBaseQuery", err)
    return
  end
  local rel_paths = util.split_lines(out)
  if #rel_paths == 0 then
    notify_info("ObsidianBaseQuery: no results")
    return
  end
  local vp = vault_path_or_error("ObsidianBaseQuery")
  if not vp then
    return
  end
  local items = {}
  for _, rel in ipairs(rel_paths) do
    table.insert(items, {
      path = util.absolute(rel, vp) or rel,
      display = rel,
    })
  end
  pickers.pick(items, { title = "Obsidian: " .. base_path .. " / " .. view })
end

-- Create a new item in a base. Accepts "<base_path> <view_name> <item_name>".
local function cmd_base_create(opts)
  local args = vim.split(vim.trim(opts.args or ""), "%s+", { trimempty = true })
  if #args < 3 then
    notify_error("ObsidianBaseCreate", "usage: :ObsidianBaseCreate <base-path> <view> <name>")
    return
  end
  local base_path = args[1]
  local view = args[2]
  local name = table.concat(args, " ", 3)
  local _, err = cli.run({
    "base:create",
    "path=" .. base_path,
    "view=" .. view,
    "name=" .. name,
  })
  if err then
    notify_error("ObsidianBaseCreate", err)
    return
  end
  notify_info("Created `" .. name .. "` in " .. base_path .. " / " .. view)
end

-- ============================================================================
-- Plugin management — wrap `obsidian plugin*` commands
-- ============================================================================

local function cmd_plugin_info(opts)
  local id = vim.trim(opts.args or "")
  if id == "" then
    notify_error("ObsidianPluginInfo", "plugin id required")
    return
  end
  local out, err = cli.run({ "plugin", "id=" .. id })
  if err then
    notify_error("ObsidianPluginInfo", err)
    return
  end
  vim.notify(out, vim.log.levels.INFO, { title = "Obsidian plugin: " .. id })
end

local function cmd_plugin_install(opts)
  local id = vim.trim(opts.args or "")
  if id == "" then
    notify_error("ObsidianPluginInstall", "plugin id required")
    return
  end
  notify_info("Installing " .. id .. "...")
  local _, err = cli.run({ "plugin:install", "id=" .. id, "enable" })
  if err then
    notify_error("ObsidianPluginInstall", err)
    return
  end
  notify_info("Installed and enabled: " .. id)
end

local function cmd_plugin_uninstall(opts)
  local id = vim.trim(opts.args or "")
  if id == "" then
    notify_error("ObsidianPluginUninstall", "plugin id required")
    return
  end
  -- Destructive — deletes files from .obsidian/plugins/<id>/
  if
    not confirm_destructive(
      "Uninstall community plugin `"
        .. id
        .. "`?\nThis deletes its folder under .obsidian/plugins/. Not reversible."
    )
  then
    notify_info("Cancelled: uninstall " .. id)
    return
  end
  local _, err = cli.run({ "plugin:uninstall", "id=" .. id })
  if err then
    notify_error("ObsidianPluginUninstall", err)
    return
  end
  notify_info("Uninstalled: " .. id)
end

local function cmd_plugin_enable(opts)
  local id = vim.trim(opts.args or "")
  if id == "" then
    notify_error("ObsidianPluginEnable", "plugin id required")
    return
  end
  local _, err = cli.run({ "plugin:enable", "id=" .. id })
  if err then
    notify_error("ObsidianPluginEnable", err)
    return
  end
  notify_info("Enabled: " .. id)
end

-- Disable a plugin. Confirms because disabling a core plugin (e.g. backlink,
-- file-explorer, graph) can silently break foundational Obsidian features.
-- Community plugins get the same confirmation for consistency.
local function cmd_plugin_disable(opts)
  local id = vim.trim(opts.args or "")
  if id == "" then
    notify_error("ObsidianPluginDisable", "plugin id required")
    return
  end
  if not confirm_destructive("Disable plugin `" .. id .. "`?") then
    notify_info("Cancelled: disable " .. id)
    return
  end
  local _, err = cli.run({ "plugin:disable", "id=" .. id })
  if err then
    notify_error("ObsidianPluginDisable", err)
    return
  end
  notify_info("Disabled: " .. id)
end

local function cmd_plugin_reload(opts)
  local id = vim.trim(opts.args or "")
  if id == "" then
    notify_error("ObsidianPluginReload", "plugin id required")
    return
  end
  local _, err = cli.run({ "plugin:reload", "id=" .. id })
  if err then
    notify_error("ObsidianPluginReload", err)
    return
  end
  notify_info("Reloaded: " .. id)
end

-- Fetch all installed plugins with their enabled state as a map {id = bool}.
local function fetch_plugin_state()
  local installed, err1 = cli.run_json({ "plugins", "format=json", "versions" })
  if err1 then
    return nil, err1
  end
  local enabled, err2 = cli.run_json({ "plugins:enabled", "format=json" })
  if err2 then
    return nil, err2
  end
  local enabled_set = {}
  if type(enabled) == "table" then
    for _, e in ipairs(enabled) do
      local id = (type(e) == "table" and (e.id or e.name)) or tostring(e)
      enabled_set[id] = true
    end
  end
  local plugins = {}
  if type(installed) == "table" then
    for _, p in ipairs(installed) do
      local id = (type(p) == "table" and (p.id or p.name)) or tostring(p)
      local version = type(p) == "table" and p.version or nil
      table.insert(plugins, {
        id = id,
        version = version,
        enabled = enabled_set[id] == true,
      })
    end
  end
  return plugins, nil
end

-- Query whether restricted (safe) mode is currently active. Returns true
-- if on, false if off or unknown. Used by the plugin picker to show a
-- banner when community plugins are suspended as a group.
local function is_restricted_mode_on()
  local out, err = cli.run({ "plugins:restrict" })
  if err or not out then
    return false
  end
  -- CLI output is something like "on" or "off" (plus optional text).
  return vim.trim(out):lower():match("^on") ~= nil
end

local function cmd_plugin_list()
  local plugins, err = fetch_plugin_state()
  if err then
    notify_error("ObsidianPluginList", err)
    return
  end
  if not plugins or #plugins == 0 then
    notify_info("ObsidianPluginList: no community plugins installed")
    return
  end
  -- Sort: enabled first, then alphabetical by id.
  table.sort(plugins, function(a, b)
    if a.enabled ~= b.enabled then
      return a.enabled
    end
    return a.id < b.id
  end)
  local restricted = is_restricted_mode_on()
  local title = restricted
      and "⚠ Obsidian plugins — RESTRICTED MODE ON (community plugins suspended)"
    or "Obsidian plugins (✓ = enabled):"
  pickers.select(plugins, {
    prompt = title,
    format_item = function(p)
      local mark = p.enabled and "✓" or "○"
      local ver = p.version and p.version ~= "" and (" v" .. p.version) or ""
      return string.format("%s  %s%s", mark, p.id, ver)
    end,
  }, function(choice)
    if not choice then
      return
    end
    local actions = choice.enabled
        and { "Disable", "Reload", "Uninstall", "Info", "Cancel" }
      or { "Enable", "Uninstall", "Info", "Cancel" }
    pickers.select(actions, {
      prompt = choice.id .. ":",
    }, function(action)
      if not action or action == "Cancel" then
        return
      end
      if action == "Enable" then
        cmd_plugin_enable({ args = choice.id })
      elseif action == "Disable" then
        cmd_plugin_disable({ args = choice.id })
      elseif action == "Reload" then
        cmd_plugin_reload({ args = choice.id })
      elseif action == "Uninstall" then
        cmd_plugin_uninstall({ args = choice.id })
      elseif action == "Info" then
        cmd_plugin_info({ args = choice.id })
      end
    end)
  end)
end

local function cmd_restricted_mode(opts)
  local arg = vim.trim(opts.args or "")
  if arg == "on" then
    local _, err = cli.run({ "plugins:restrict", "on" })
    if err then
      notify_error("ObsidianRestrictedMode", err)
      return
    end
    notify_info("Restricted mode ON (all community plugins disabled)")
  elseif arg == "off" then
    local _, err = cli.run({ "plugins:restrict", "off" })
    if err then
      notify_error("ObsidianRestrictedMode", err)
      return
    end
    notify_info("Restricted mode OFF (community plugins restored)")
  else
    -- Report current state.
    local out, err = cli.run({ "plugins:restrict" })
    if err then
      notify_error("ObsidianRestrictedMode", err)
      return
    end
    notify_info("Restricted mode: " .. vim.trim(out))
  end
end

local function cmd_start()
  local opener
  if vim.fn.has("mac") == 1 then
    opener = { "open", "-a", "Obsidian" }
  elseif vim.fn.has("unix") == 1 then
    opener = { "xdg-open", "obsidian://" }
  elseif vim.fn.has("win32") == 1 then
    opener = { "cmd", "/c", "start", "obsidian://" }
  else
    notify_error("ObsidianStart", "unsupported platform")
    return
  end
  local result = vim.system(opener, { detach = true }):wait()
  if result.code ~= 0 then
    notify_error("ObsidianStart", "failed to launch Obsidian")
    return
  end
  cli.reset_vault_cache()
  notify_info("Launching Obsidian — wait a moment then retry your command")
end

function M.register(_)
  local cmd = vim.api.nvim_create_user_command
  cmd("ObsidianStart", cmd_start, { desc = "Launch the Obsidian desktop app" })
  cmd("ObsidianCommand", cmd_command, {
    desc = "Execute any registered Obsidian command by ID",
    nargs = "+",
  })
  cmd("ObsidianCommandList", cmd_command_list, {
    desc = "List and execute Obsidian commands (optional filter prefix)",
    nargs = "?",
  })
  cmd("ObsidianPluginList", cmd_plugin_list, {
    desc = "Browse installed plugins and enable/disable/uninstall/reload",
  })
  cmd("ObsidianPluginInfo", cmd_plugin_info, {
    desc = "Show info for a specific plugin by ID",
    nargs = "+",
  })
  cmd("ObsidianPluginInstall", cmd_plugin_install, {
    desc = "Install a community plugin by ID and auto-enable",
    nargs = "+",
  })
  cmd("ObsidianPluginUninstall", cmd_plugin_uninstall, {
    desc = "Uninstall a community plugin by ID (with confirmation)",
    nargs = "+",
  })
  cmd("ObsidianPluginEnable", cmd_plugin_enable, {
    desc = "Enable an installed plugin by ID",
    nargs = "+",
  })
  cmd("ObsidianPluginDisable", cmd_plugin_disable, {
    desc = "Disable an installed plugin by ID",
    nargs = "+",
  })
  cmd("ObsidianPluginReload", cmd_plugin_reload, {
    desc = "Hot-reload a plugin (for plugin developers)",
    nargs = "+",
  })
  cmd("ObsidianRestrictedMode", cmd_restricted_mode, {
    desc = "Toggle or check Obsidian's restricted (safe) mode",
    nargs = "?",
  })
  cmd("ObsidianBases", cmd_bases, {
    desc = "List all .base files in the vault",
  })
  cmd("ObsidianBaseViews", cmd_base_views, {
    desc = "List views in a .base file",
    nargs = "?",
  })
  cmd("ObsidianBaseQuery", cmd_base_query, {
    desc = "Query a base view: :ObsidianBaseQuery <base-path> <view>",
    nargs = "+",
  })
  cmd("ObsidianBaseCreate", cmd_base_create, {
    desc = "Create an item in a base: :ObsidianBaseCreate <base> <view> <name>",
    nargs = "+",
  })
  cmd("ObsidianToday", cmd_today, { desc = "Open today's daily note" })
  cmd("ObsidianTask", cmd_task, { desc = "Append a task to today's note", nargs = "+" })
  cmd("ObsidianTodo", cmd_todo, { desc = "Append a todo to today's note", nargs = "+" })
  cmd("ObsidianAppend", cmd_append, { desc = "Append text to today's note", nargs = "+" })
  cmd("ObsidianTasksToday", cmd_tasks_today, { desc = "Show today's incomplete tasks" })
  cmd("ObsidianTaskToggle", cmd_task_toggle, { desc = "Toggle the task on the current line" })
  cmd("ObsidianResolveLink", cmd_resolve_link, {
    desc = "Create a note from the [[wiki link]] under the cursor",
  })
  cmd("ObsidianFollowLink", cmd_follow_link, {
    desc = "Follow the [[wiki link]] under the cursor; offer to create if missing",
  })
  cmd("ObsidianNew", cmd_new, { desc = "Create a new note", nargs = "+" })
  cmd("ObsidianNewFrom", cmd_new_from, { desc = "Create a new note from a template", nargs = "+" })
  cmd("ObsidianFind", cmd_find, { desc = "Find a note in the vault" })
  cmd("ObsidianRecent", cmd_recent, { desc = "Pick from recently modified notes" })
  cmd("ObsidianSearch", cmd_search, { desc = "Full-text search the vault", nargs = "*" })
  cmd("ObsidianBacklinks", cmd_backlinks, { desc = "Show backlinks for the current note" })
  cmd("ObsidianUnresolved", cmd_unresolved, { desc = "List unresolved links in the vault" })
end

return M
