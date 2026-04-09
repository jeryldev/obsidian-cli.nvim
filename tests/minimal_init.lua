-- Minimal Neovim init for running obsidian-cli.nvim tests.
-- Loads plenary.nvim (test harness) and our plugin into the runtimepath,
-- then configures any globals the tests need. Kept deliberately small:
-- no colorscheme, no LSP, no user config bleed.

local function add_rtp(path)
  path = vim.fn.expand(path)
  if vim.fn.isdirectory(path) == 1 then
    vim.opt.runtimepath:prepend(path)
  end
end

-- plenary — required for test harness
add_rtp("~/.local/share/nvim/lazy/plenary.nvim")
-- our plugin under test
add_rtp(vim.fn.fnamemodify(vim.fn.expand("<sfile>:p"), ":h:h"))

vim.cmd("runtime plugin/plenary.vim")
