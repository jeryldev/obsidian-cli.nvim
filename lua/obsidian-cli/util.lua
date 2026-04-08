local M = {}

local function trim_trailing_slash(p)
  return (p:gsub("/+$", ""))
end

function M.expand(path)
  if not path or path == "" then
    return path
  end
  return vim.fn.expand(path)
end

function M.is_absolute(path)
  return path:sub(1, 1) == "/"
end

function M.absolute(relpath, vault_path)
  if not relpath or relpath == "" then
    return nil
  end
  if M.is_absolute(relpath) then
    return relpath
  end
  if not vault_path or vault_path == "" then
    return relpath
  end
  return trim_trailing_slash(M.expand(vault_path)) .. "/" .. relpath
end

function M.relative_to_vault(abspath, vault_path)
  if not abspath or abspath == "" then
    return abspath
  end
  if not vault_path or vault_path == "" then
    return abspath
  end
  local vault = trim_trailing_slash(M.expand(vault_path)) .. "/"
  if vim.startswith(abspath, vault) then
    return abspath:sub(#vault + 1)
  end
  return abspath
end

function M.in_vault(path, vault_path)
  if not path or path == "" or not vault_path or vault_path == "" then
    return false
  end
  local vault = trim_trailing_slash(M.expand(vault_path)) .. "/"
  return vim.startswith(path, vault)
end

function M.split_lines(s)
  if not s or s == "" then
    return {}
  end
  return vim.split(vim.trim(s), "\n", { trimempty = true })
end

return M
