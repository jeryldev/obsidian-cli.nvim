local M = {}

local config

local function detect()
  if pcall(require, "snacks") then
    return "snacks"
  end
  return "quickfix"
end

local function backend()
  local picked = (config and config.picker) or detect()
  return picked
end

function M.setup(c)
  config = c
end

function M.pick(items, opts)
  local kind = backend()
  if kind == "snacks" then
    local ok = require("obsidian-cli.pickers.snacks").files(items, opts)
    if ok then
      return
    end
  end
  require("obsidian-cli.pickers.quickfix").files(items, opts)
end

return M
