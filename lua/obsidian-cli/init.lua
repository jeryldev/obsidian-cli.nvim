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
  prompt("<leader>os", "ObsidianSearch", "Obsidian: search")
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

local function set_buffer_keymap(buf)
  if not M.config or not M.config.keymaps then
    return
  end
  vim.keymap.set("n", "<leader>ob", "<cmd>ObsidianBacklinks<cr>", {
    buffer = buf,
    desc = "Obsidian: backlinks",
    silent = true,
  })
end

local function register_vault_autocmd()
  local group = vim.api.nvim_create_augroup("ObsidianCli", { clear = true })
  vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
    group = group,
    pattern = "*.md",
    callback = function(ev)
      local path = vim.api.nvim_buf_get_name(ev.buf)
      if path == "" then
        return
      end
      local vp = (cli.vault_path())
      if not vp or not util.in_vault(path, vp) then
        return
      end
      apply_buffer_options(ev.buf)
      set_buffer_keymap(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "markdown",
    callback = function(ev)
      local path = vim.api.nvim_buf_get_name(ev.buf)
      if path == "" then
        return
      end
      local vp = (cli.vault_path())
      if not vp or not util.in_vault(path, vp) then
        return
      end
      apply_buffer_options(ev.buf)
      set_buffer_keymap(ev.buf)
    end,
  })
end

function M.setup(opts)
  M.config = config_module.merge(opts)
  cli.setup(M.config)
  pickers.setup(M.config)
  commands.register(M.config)

  if M.config.keymaps then
    set_global_keymaps()
  end

  if M.config.buffer_options then
    register_vault_autocmd()
  end
end

return M
