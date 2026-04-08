local M = {}

function M.files(items, opts)
  opts = opts or {}
  local qf = {}
  for _, item in ipairs(items) do
    table.insert(qf, {
      filename = item.path,
      lnum = item.lnum or 1,
      col = 1,
      text = item.text or item.display or item.path,
    })
  end
  vim.fn.setqflist({}, " ", { title = opts.title or "obsidian-cli", items = qf })
  if #qf == 0 then
    vim.notify((opts.title or "obsidian-cli") .. ": no results", vim.log.levels.INFO)
    return
  end
  vim.cmd("copen")
end

return M
