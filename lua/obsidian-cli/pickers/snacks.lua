local M = {}

local function snacks_ok()
  local ok, snacks = pcall(require, "snacks")
  return ok and snacks or nil
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
    })
  end
  snacks.picker.pick({
    source = "obsidian-cli",
    title = opts.title or "obsidian-cli",
    items = snacks_items,
    format = "file",
    confirm = function(picker, item)
      picker:close()
      if item and item.file then
        vim.cmd.edit(vim.fn.fnameescape(item.file))
        if item.pos then
          pcall(vim.api.nvim_win_set_cursor, 0, item.pos)
        end
      end
    end,
  })
  return true
end

return M
