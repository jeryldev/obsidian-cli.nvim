local M = {}

M.defaults = {
  binary = "obsidian",
  vault = nil,
  vault_path = nil,
  picker = nil,
  keymaps = true,
  buffer_options = {
    wrap = true,
    linebreak = true,
    breakindent = true,
    colorcolumn = "80",
    spell = true,
    conceallevel = 2,
  },
}

function M.merge(opts)
  return vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
