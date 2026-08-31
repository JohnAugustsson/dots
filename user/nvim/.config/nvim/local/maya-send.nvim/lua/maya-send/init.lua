local bootstrap = require("maya-send.bootstrap")
local config = require("maya-send.config")
local dedent = require("maya-send.dedent")
local transport = require("maya-send.transport")

local M = {}

local function write_file(path, contents)
  local file, err = io.open(path, "w")
  if not file then
    return false, err or ("cannot write to " .. path)
  end

  file:write(contents)
  file:close()
  return true
end

-- Runs `lines` in Maya's `__main__`, so imports and definitions stick around
-- for the next send.
function M.send_lines(lines)
  local cfg = config.options
  local code = table.concat(lines, "\n")

  if code:match("^%s*$") then
    vim.notify("No code to send to Maya!", vim.log.levels.WARN)
    return
  end

  local ok, err = write_file(cfg.files.code, code)
  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  local boot_source, render_err = bootstrap.render(cfg.files.code, cfg.files.output)
  if not boot_source then
    vim.notify(render_err, vim.log.levels.ERROR)
    return
  end

  ok, err = write_file(cfg.files.bootstrap, boot_source)
  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  vim.notify("Connecting to Maya at " .. cfg.host .. "...", vim.log.levels.INFO)

  transport.send_mel(cfg, transport.exec_file_command(cfg.files.bootstrap), function(send_err, stage)
    if not send_err then
      vim.notify("Code sent to Maya!", vim.log.levels.INFO)
    elseif stage == "connect" then
      vim.notify(
        string.format("Connection failed (%s:%d)\nIs Maya running with commandPort open?", cfg.host, cfg.port),
        vim.log.levels.ERROR
      )
    else
      vim.notify("Write failed: " .. tostring(send_err), vim.log.levels.ERROR)
    end
  end)
end

function M.send_buffer()
  M.send_lines(vim.api.nvim_buf_get_lines(0, 0, -1, false))
end

function M.send_selection()
  local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), {
    type = vim.fn.mode(),
    exclusive = false,
  })

  M.send_lines(dedent.dedent(lines, vim.bo.tabstop))
end

function M.send_range(first, last)
  M.send_lines(dedent.dedent(vim.api.nvim_buf_get_lines(0, first - 1, last, false), vim.bo.tabstop))
end

function M.setup(opts)
  local cfg = config.set(opts)

  vim.api.nvim_create_user_command("MayaSend", function(args)
    if args.range > 0 then
      M.send_range(args.line1, args.line2)
    else
      M.send_buffer()
    end
  end, { range = true, desc = "Send Python code to Maya" })

  if cfg.keys.send then
    vim.keymap.set("n", cfg.keys.send, M.send_buffer, { desc = "Send entire file to Maya" })
    vim.keymap.set("x", cfg.keys.send, M.send_selection, { desc = "Send selection to Maya" })
  end
end

return M
