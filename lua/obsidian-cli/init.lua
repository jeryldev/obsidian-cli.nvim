local M = {}

local config_module = require("obsidian-cli.config")
local cli = require("obsidian-cli.cli")
local commands = require("obsidian-cli.commands")
local pickers = require("obsidian-cli.pickers")
local util = require("obsidian-cli.util")

M.config = nil

local function set_global_keymaps()
  local cmd = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { desc = desc, silent = true })
  end
  local prompt = function(lhs, prefix, desc)
    vim.keymap.set("n", lhs, function()
      vim.api.nvim_input(":" .. prefix .. " ")
    end, { desc = desc })
  end
  cmd("<leader>ot", "<cmd>ObsidianToday<cr>", "Obsidian: today")
  prompt("<leader>oT", "ObsidianTask", "Obsidian: task capture")
  prompt("<leader>oa", "ObsidianAppend", "Obsidian: append to today")
  prompt("<leader>on", "ObsidianNew", "Obsidian: new note")
  prompt("<leader>oN", "ObsidianNewFrom", "Obsidian: new from template")
  cmd("<leader>of", "<cmd>ObsidianFind<cr>", "Obsidian: find note")
  cmd("<leader>fo", "<cmd>ObsidianFind<cr>", "Find obsidian notes")
  cmd("<leader>or", "<cmd>ObsidianRecent<cr>", "Obsidian: recent notes")
  cmd("<leader>os", "<cmd>ObsidianSearch<cr>", "Obsidian: live search")
  cmd("<leader>ox", "<cmd>ObsidianTasksToday<cr>", "Obsidian: today's tasks")
  cmd("<leader>ou", "<cmd>ObsidianUnresolved<cr>", "Obsidian: unresolved links")
end

local function apply_buffer_options(buf)
  if not M.config or not M.config.buffer_options then
    return
  end
  for k, v in pairs(M.config.buffer_options) do
    pcall(function()
      vim.api.nvim_set_option_value(k, v, { scope = "local", buf = buf })
    end)
  end
end

local function maybe_disable_diagnostics(buf)
  if not M.config or not M.config.disable_diagnostics_in_vault then
    return
  end
  pcall(vim.diagnostic.enable, false, { bufnr = buf })
end

local function set_buffer_keymap(buf)
  if not M.config or not M.config.keymaps then
    return
  end
  vim.keymap.set("n", "<leader>ob", "<cmd>ObsidianBacklinks<cr>", {
    buffer = buf,
    desc = "Obsidian: backlinks",
    silent = true,
  })
  vim.keymap.set("n", "<leader>oc", "<cmd>ObsidianTaskToggle<cr>", {
    buffer = buf,
    desc = "Obsidian: toggle task on current line",
    silent = true,
  })
  vim.keymap.set("n", "<leader>oR", "<cmd>ObsidianResolveLink<cr>", {
    buffer = buf,
    desc = "Obsidian: create note from [[link]] under cursor",
    silent = true,
  })
  vim.keymap.set("n", "<leader>ol", "<cmd>ObsidianFollowLink<cr>", {
    buffer = buf,
    desc = "Obsidian: follow [[link]] under cursor (create if missing)",
    silent = true,
  })
end

local function maybe_apply_to_buffer(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" then
    return
  end
  local vp = cli.vault_path()
  if not vp or not util.in_vault(path, vp) then
    return
  end
  apply_buffer_options(buf)
  maybe_disable_diagnostics(buf)
  set_buffer_keymap(buf)
end

local function register_vault_autocmd()
  local group = vim.api.nvim_create_augroup("ObsidianCli", { clear = true })
  -- Catch every way a markdown buffer can come into existence with a vault path:
  --   - opening an existing file (BufWinEnter / FileType)
  --   - saving a no-name buffer to a path (BufFilePost / BufWritePost)
  --   - renaming via :file (BufFilePost)
  vim.api.nvim_create_autocmd(
    { "FileType", "BufWinEnter", "BufFilePost", "BufWritePost" },
    {
      group = group,
      pattern = { "markdown", "*.md" },
      callback = function(ev)
        maybe_apply_to_buffer(ev.buf)
      end,
    }
  )
end

function M.setup(opts)
  M.config = config_module.merge(opts)
  cli.setup(M.config)
  pickers.setup(M.config)
  commands.register(M.config)

  if M.config.keymaps then
    set_global_keymaps()
  end

  -- Register the vault buffer autocmd if ANY buffer-scoped behavior is
  -- enabled — buffer options, diagnostics scoping, OR buffer-local keymaps.
  -- Earlier this was gated only on `buffer_options`, which silently dropped
  -- `<leader>ob`/`<leader>oc`/`<leader>oR` for users who set `buffer_options = false`.
  local needs_autocmd = M.config.buffer_options
    or M.config.disable_diagnostics_in_vault
    or M.config.keymaps
  if needs_autocmd then
    register_vault_autocmd()
  end
end

return M
