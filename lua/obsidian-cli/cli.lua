local M = {}

local config

function M.setup(c)
  config = c
end

local function build_cmd(args)
  local cmd = { config.binary or "obsidian" }
  if config.vault and config.vault ~= "" then
    table.insert(cmd, "vault=" .. config.vault)
  end
  for _, a in ipairs(args) do
    table.insert(cmd, a)
  end
  return cmd
end

function M.run(args)
  local cmd = build_cmd(args)
  local ok, result = pcall(function()
    return vim.system(cmd, { text = true }):wait()
  end)
  if not ok then
    return nil, "failed to spawn obsidian: " .. tostring(result)
  end
  if result.code ~= 0 then
    local msg = result.stderr
    if not msg or msg == "" then
      msg = result.stdout
    end
    msg = vim.trim(msg or "")
    if msg == "" then
      msg = "obsidian exited with code " .. tostring(result.code)
    end
    return nil, msg
  end
  return result.stdout or "", nil
end

function M.run_json(args)
  local out, err = M.run(args)
  if err then
    return nil, err
  end
  out = vim.trim(out)
  if out == "" then
    return nil, "empty response from obsidian cli"
  end
  local ok, decoded = pcall(vim.json.decode, out)
  if not ok then
    return nil, "failed to parse JSON: " .. tostring(decoded)
  end
  return decoded, nil
end

local cached_vault_path

function M.vault_path()
  if config.vault_path and config.vault_path ~= "" then
    return vim.fn.expand(config.vault_path)
  end
  if cached_vault_path then
    return cached_vault_path
  end
  local out, err = M.run({ "vault", "info=path" })
  if err then
    return nil, err
  end
  cached_vault_path = vim.trim(out)
  if cached_vault_path == "" then
    cached_vault_path = nil
    return nil, "obsidian returned empty vault path"
  end
  return cached_vault_path
end

function M.reset_vault_cache()
  cached_vault_path = nil
end

function M.version()
  local out, err = M.run({ "version" })
  if err then
    return nil, err
  end
  return vim.trim(out), nil
end

return M
