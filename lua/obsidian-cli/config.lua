local M = {}

M.defaults = {
  binary = "obsidian",
  vault = nil,
  vault_path = nil,
  picker = nil,
  keymaps = true,
  -- Max number of entries shown by :ObsidianRecent. The plugin enumerates
  -- all vault markdown files, sorts by mtime, and trims to this count.
  recent_limit = 20,
  -- Disable diagnostics inside vault markdown buffers (e.g. markdownlint
  -- noise about MD041, MD012). Set to false to keep diagnostics enabled.
  disable_diagnostics_in_vault = true,
  buffer_options = {
    wrap = true,
    linebreak = true,
    breakindent = true,
    colorcolumn = "80",
    spell = false,
    conceallevel = 2,
  },
}

function M.merge(opts)
  return vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
