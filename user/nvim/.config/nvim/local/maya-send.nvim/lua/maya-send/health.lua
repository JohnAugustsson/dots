local bootstrap = require("maya-send.bootstrap")
local config = require("maya-send.config")

local M = {}

local uv = vim.uv or vim.loop

local CONNECT_TIMEOUT = 500

local function probe(host, port)
  local tcp = uv.new_tcp()
  if not tcp then
    return "could not open a TCP handle"
  end

  local result

  tcp:connect(host, port, function(err)
    result = err or false
  end)

  vim.wait(CONNECT_TIMEOUT, function()
    return result ~= nil
  end)

  tcp:close()

  if result == nil then
    return "timed out"
  end

  return result or nil
end

function M.check()
  local cfg = config.options

  vim.health.start("maya-send")

  local runner = bootstrap.runner_path()
  if runner then
    vim.health.ok("runner script: " .. runner)
  else
    vim.health.error("python/maya_runner.py not found on the runtimepath")
  end

  local err = probe(cfg.host, cfg.port)
  if err then
    vim.health.warn(
      string.format("cannot reach %s:%d (%s)", cfg.host, cfg.port, err),
      { 'in Maya: cmds.commandPort(name=":' .. cfg.port .. '", sourceType="mel")' }
    )
  else
    vim.health.ok(string.format("commandPort reachable at %s:%d", cfg.host, cfg.port))
  end
end

return M
