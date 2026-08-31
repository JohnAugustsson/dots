local M = {}

local uv = vim.uv or vim.loop

-- A MEL string literal, for wrapping Python in a `python("...")` call.
local function mel_string(value)
  return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

function M.exec_file_command(path)
  return string.format("python(%s);", mel_string(string.format("exec(open(%s).read())", mel_string(path))))
end

-- Sends one MEL command to Maya's commandPort. `on_result` is called on the
-- main loop with (err, stage), where err is nil on success.
function M.send_mel(cfg, command, on_result)
  local tcp = uv.new_tcp()
  if not tcp then
    vim.schedule(function()
      on_result("could not open a TCP handle", "connect")
    end)
    return
  end

  local function finish(err, stage)
    tcp:close()
    vim.schedule(function()
      on_result(err, stage)
    end)
  end

  tcp:connect(cfg.host, cfg.port, function(conn_err)
    if conn_err then
      return finish(conn_err, "connect")
    end

    tcp:write(command .. "\n", function(write_err)
      if write_err then
        return finish(write_err, "write")
      end

      -- Graceful shutdown sends FIN, so Maya drains the buffer before closing.
      tcp:shutdown(function()
        finish(nil)
      end)
    end)
  end)
end

return M
