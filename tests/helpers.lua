-- Shared test helpers for mocking cli.run/run_json and capturing picker/notify calls.

local M = {}

local cli = require("obsidian-cli.cli")
local pickers = require("obsidian-cli.pickers")

-- Stores the real functions so we can restore them.
M._real_system = vim.system
M._real_notify = vim.notify

-- Mock vim.system to return canned CLI responses.
-- Accepts a table of { [subcommand] = { stdout, stderr, code } } or a
-- single { stdout, stderr, code } that applies to all calls.
function M.mock_cli(responses)
  if responses.stdout then
    -- Single canned response for all calls.
    vim.system = function()
      return {
        wait = function()
          return {
            code = responses.code or 0,
            stdout = responses.stdout or "",
            stderr = responses.stderr or "",
          }
        end,
      }
    end
    return
  end
  -- Per-subcommand responses. The first CLI arg (after "obsidian") is the key.
  vim.system = function(cmd)
    local key = cmd[2] or "unknown"
    local resp = responses[key] or { stdout = "", stderr = "unmatched: " .. key, code = 1 }
    return {
      wait = function()
        return {
          code = resp.code or 0,
          stdout = resp.stdout or "",
          stderr = resp.stderr or "",
        }
      end,
    }
  end
end

-- Capture vim.notify calls instead of displaying them.
M.notifications = {}

function M.capture_notifications()
  M.notifications = {}
  vim.notify = function(msg, level, opts)
    table.insert(M.notifications, { msg = msg, level = level, opts = opts })
  end
end

-- Capture pickers.pick calls instead of opening a real picker.
M.picker_calls = {}

function M.capture_pickers()
  M.picker_calls = {}
  pickers.pick = function(items, opts)
    table.insert(M.picker_calls, { items = items, opts = opts })
  end
  pickers.select = function(items, opts, on_choice)
    table.insert(M.picker_calls, { items = items, opts = opts, select = true })
    -- Auto-select first item for test flow.
    if on_choice and #items > 0 then
      on_choice(items[1])
    end
  end
  pickers.live_search = function(opts)
    table.insert(M.picker_calls, { live = true, opts = opts })
  end
end

-- Restore all mocks.
function M.restore()
  vim.system = M._real_system
  vim.notify = M._real_notify
  -- Re-require to reset pickers module state.
  package.loaded["obsidian-cli.pickers"] = nil
  package.loaded["obsidian-cli.pickers.snacks"] = nil
  package.loaded["obsidian-cli.pickers.quickfix"] = nil
  package.loaded["obsidian-cli.pickers.init"] = nil
end

-- Setup the plugin with mocked CLI for testing.
function M.setup_with_mock(cli_responses, plugin_opts)
  -- Clear all cached modules so fresh requires pick up mocks.
  for key, _ in pairs(package.loaded) do
    if key:match("^obsidian%-cli") then
      package.loaded[key] = nil
    end
  end

  M.mock_cli(cli_responses)
  M.capture_notifications()

  -- Require pickers fresh, then mock its functions. Commands module will
  -- get the same cached (now-mocked) pickers reference when it loads.
  local fresh_pickers = require("obsidian-cli.pickers")
  M.picker_calls = {}
  fresh_pickers.pick = function(items, opts)
    table.insert(M.picker_calls, { items = items, opts = opts })
  end
  fresh_pickers.select = function(items, opts, on_choice)
    table.insert(M.picker_calls, { items = items, opts = opts, select = true })
    if on_choice and #items > 0 then
      on_choice(items[1])
    end
  end
  fresh_pickers.live_search = function(opts)
    table.insert(M.picker_calls, { live = true, opts = opts })
  end

  -- Now setup the plugin — commands.lua will require the same (mocked) pickers.
  local plugin = require("obsidian-cli")
  plugin.setup(plugin_opts or { keymaps = false })
  -- Reset vault path cache so each test gets a fresh resolution.
  require("obsidian-cli.cli").reset_vault_cache()
  return plugin
end

-- Incrementing counter for unique buffer names.
M._buf_counter = 0

-- Create a temporary buffer with given lines and an optional name.
-- Uses a unique name per call to avoid E95 (buffer name collision).
function M.create_buffer(lines, filetype)
  M._buf_counter = M._buf_counter + 1
  local buf = vim.api.nvim_create_buf(false, true) -- nofile scratch buffer
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].swapfile = false
  vim.api.nvim_set_current_buf(buf)
  if filetype then
    vim.bo[buf].filetype = filetype
  end
  return buf
end

-- Set a unique buffer name scoped to the vault path. Avoids E95.
function M.set_buf_name(buf, base_name)
  M._buf_counter = M._buf_counter + 1
  local unique = base_name:gsub("%.md$", "") .. "_" .. M._buf_counter .. ".md"
  pcall(vim.api.nvim_buf_set_name, buf, unique)
  return unique
end

-- Get the last notification message (or nil).
function M.last_notification()
  if #M.notifications == 0 then
    return nil
  end
  return M.notifications[#M.notifications].msg
end

-- Get the last picker call (or nil).
function M.last_picker()
  if #M.picker_calls == 0 then
    return nil
  end
  return M.picker_calls[#M.picker_calls]
end

return M
