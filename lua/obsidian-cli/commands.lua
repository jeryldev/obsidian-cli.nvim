local M = {}

local cli = require("obsidian-cli.cli")
local util = require("obsidian-cli.util")
local pickers = require("obsidian-cli.pickers")

local function notify_error(name, err)
  vim.notify(name .. ": " .. tostring(err), vim.log.levels.ERROR)
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

local function cmd_today()
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

local function cmd_tasks_today()
  local data, err = cli.run_json({ "tasks", "daily", "todo", "format=json" })
  if err then
    notify_error("ObsidianTasksToday", err)
    return
  end
  local vp = vault_path_or_error("ObsidianTasksToday") or ""
  local items = {}
  if type(data) == "table" then
    for _, entry in ipairs(data) do
      local rel = entry.file or entry.path or ""
      local abs = util.absolute(rel, vp) or rel
      table.insert(items, {
        path = abs,
        lnum = entry.line or entry.lnum or 1,
        text = entry.text or entry.task or rel,
      })
    end
  end
  pickers.pick(items, { title = "Obsidian: today's tasks" })
end

local function cmd_new(opts)
  local title = opts.args
  if title == "" then
    notify_error("ObsidianNew", "title required")
    return
  end
  local _, err = cli.run({ "create", "name=" .. title, "open" })
  if err then
    notify_error("ObsidianNew", err)
    return
  end
  notify_info("Created: " .. title)
end

local function cmd_new_from(opts)
  local args = vim.split(opts.args, "%s+", { trimempty = true })
  if #args < 2 then
    notify_error("ObsidianNewFrom", "usage: :ObsidianNewFrom <template> <title>")
    return
  end
  local template = table.remove(args, 1)
  local title = table.concat(args, " ")
  local _, err = cli.run({ "create", "name=" .. title, "template=" .. template, "open" })
  if err then
    notify_error("ObsidianNewFrom", err)
    return
  end
  notify_info("Created from " .. template .. ": " .. title)
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
  local vp = vault_path_or_error("ObsidianFind") or ""
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
  local vp = vault_path_or_error("ObsidianRecent") or ""
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
  local limit = 20
  local items = {}
  for i = 1, math.min(limit, #stamped) do
    table.insert(items, stamped[i])
  end
  pickers.pick(items, { title = "Obsidian: recent" })
end

local function cmd_search(opts)
  local query = opts.args
  if query == "" then
    notify_error("ObsidianSearch", "query required")
    return
  end
  local data, err = cli.run_json({ "search:context", "query=" .. query, "format=json" })
  if err then
    notify_error("ObsidianSearch", err)
    return
  end
  local vp = vault_path_or_error("ObsidianSearch") or ""
  local items = {}
  if type(data) == "table" then
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
            lnum = m.line or 1,
            text = m.text or "",
          })
        end
      end
    end
  end
  pickers.pick(items, { title = "Obsidian: search" })
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
    -- The CLI returns "No backlinks found." with non-zero status sometimes;
    -- treat it as an empty result rather than an error.
    if err:lower():find("no backlinks") then
      pickers.pick({}, { title = "Obsidian: backlinks (none)" })
      return
    end
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
          lnum = entry.line or 1,
          text = entry.text or f,
        })
      end
    end
  end
  pickers.pick(items, { title = "Obsidian: backlinks" })
end

local function cmd_unresolved()
  local data, err = cli.run_json({ "unresolved", "format=json", "verbose" })
  if err then
    notify_error("ObsidianUnresolved", err)
    return
  end
  local vp = vault_path_or_error("ObsidianUnresolved") or ""
  local items = {}
  if type(data) == "table" then
    for _, entry in ipairs(data) do
      if type(entry) == "string" then
        table.insert(items, { path = entry, display = entry, text = entry })
      elseif type(entry) == "table" then
        local link = entry.link or entry.target or ""
        local sources = entry.sources or entry.files or {}
        if type(sources) == "table" and #sources > 0 then
          for _, src in ipairs(sources) do
            table.insert(items, {
              path = util.absolute(src, vp) or src,
              display = src,
              text = link,
            })
          end
        else
          table.insert(items, {
            path = util.absolute(entry.file or "", vp) or "",
            display = link,
            text = link,
          })
        end
      end
    end
  end
  pickers.pick(items, { title = "Obsidian: unresolved links" })
end

function M.register(_)
  local cmd = vim.api.nvim_create_user_command
  cmd("ObsidianToday", cmd_today, { desc = "Open today's daily note" })
  cmd("ObsidianTask", cmd_task, { desc = "Append a task to today's note", nargs = "+" })
  cmd("ObsidianTodo", cmd_todo, { desc = "Append a todo to today's note", nargs = "+" })
  cmd("ObsidianAppend", cmd_append, { desc = "Append text to today's note", nargs = "+" })
  cmd("ObsidianTasksToday", cmd_tasks_today, { desc = "Show today's incomplete tasks" })
  cmd("ObsidianNew", cmd_new, { desc = "Create a new note", nargs = "+" })
  cmd("ObsidianNewFrom", cmd_new_from, { desc = "Create a new note from a template", nargs = "+" })
  cmd("ObsidianFind", cmd_find, { desc = "Find a note in the vault" })
  cmd("ObsidianRecent", cmd_recent, { desc = "Pick from recently modified notes" })
  cmd("ObsidianSearch", cmd_search, { desc = "Full-text search the vault", nargs = "+" })
  cmd("ObsidianBacklinks", cmd_backlinks, { desc = "Show backlinks for the current note" })
  cmd("ObsidianUnresolved", cmd_unresolved, { desc = "List unresolved links in the vault" })
end

return M
