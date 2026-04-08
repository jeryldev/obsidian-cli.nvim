local M = {}

local health = vim.health or require("health")
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local err = health.error or health.report_error
local info = health.info or health.report_info

function M.check()
  start("obsidian-cli.nvim")

  local plugin_ok, plugin = pcall(require, "obsidian-cli")
  if not plugin_ok or not plugin.config then
    err("plugin not loaded — call require('obsidian-cli').setup({}) in your config")
    return
  end
  ok("plugin loaded")

  local binary = plugin.config.binary or "obsidian"
  if vim.fn.executable(binary) ~= 1 then
    err(("`%s` not found on PATH"):format(binary), {
      "Install Obsidian 1.12+ from https://obsidian.md/download",
      "Enable `Settings → General → Command line interface` and register the CLI",
      "Restart your terminal so the PATH update takes effect",
    })
    return
  end
  ok(("binary `%s` found at %s"):format(binary, vim.fn.exepath(binary)))

  local cli = require("obsidian-cli.cli")
  cli.setup(plugin.config)

  local version, version_err = cli.version()
  if version_err then
    err("`obsidian version` failed: " .. version_err, {
      "Make sure the Obsidian desktop app is running",
      "The CLI talks to the live app — without it, almost nothing works",
    })
    return
  end
  ok("obsidian " .. version)

  local vp, vp_err = cli.vault_path()
  if vp_err or not vp then
    err("could not resolve vault path: " .. (vp_err or "unknown"), {
      "Open Obsidian and make sure a vault is loaded",
      "Or set `vault_path` in setup() to pin a specific path",
    })
    return
  end
  ok("vault: " .. vp)

  if vim.fn.isdirectory(vp) ~= 1 then
    warn("vault path does not exist as a directory on disk", {
      "Obsidian reported a path the filesystem does not see",
      "This is unusual — investigate your Obsidian vault setup",
    })
  end

  -- Smoke-test JSON output for one of the parsing-dependent commands.
  local _, files_err = cli.run({ "files" })
  if files_err then
    warn("`obsidian files` failed: " .. files_err)
  else
    ok("`obsidian files` works")
  end

  info("ready — try `:ObsidianToday`, `:ObsidianFind`, or `:ObsidianSearch foo`")
end

return M
