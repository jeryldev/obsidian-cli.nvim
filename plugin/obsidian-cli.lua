if vim.g.loaded_obsidian_cli == 1 then
  return
end
vim.g.loaded_obsidian_cli = 1

if vim.fn.has("nvim-0.10") ~= 1 then
  vim.notify("obsidian-cli.nvim requires Neovim 0.10+", vim.log.levels.ERROR)
  return
end
