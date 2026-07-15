-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
require("config.project_picker").setup()

local stash = "z"

vim.opt.clipboard = "unnamedplus"

vim.keymap.set({ "n", "x" }, "<M-p>", '"' .. stash .. "p", { noremap = true, silent = true })
vim.keymap.set({ "n", "x" }, "<M-P>", '"' .. stash .. "P", { noremap = true, silent = true })

local swedish_bracket_ns = vim.api.nvim_create_namespace("swedish_bracket_remap")
local swedish_bracket_map = {
  ["å"] = "[",
  ["¨"] = "]",
  ["ö"] = "{",
  ["ä"] = "}",
  ["Å"] = "{",
  ["^"] = "}",
}

vim.on_key(nil, swedish_bracket_ns)
vim.on_key(function(key, typed)
  local replacement = swedish_bracket_map[typed]
  if not replacement then
    return nil
  end

  local mode = vim.api.nvim_get_mode().mode
  if mode:sub(1, 1) == "t" then
    return nil
  end

  vim.schedule(function()
    vim.api.nvim_input(replacement)
  end)
  return ""
end, swedish_bracket_ns)

vim.keymap.set(
  { "n", "x" },
  "d",
  '"' .. stash .. "d",
  { noremap = true, silent = true, desc = "Delete To Stash Register" }
)
vim.keymap.set(
  "n",
  "D",
  '"' .. stash .. "D",
  { noremap = true, silent = true, desc = "Delete Line Tail To Stash Register" }
)

vim.keymap.set(
  { "n", "x" },
  "c",
  '"' .. stash .. "c",
  { noremap = true, silent = true, desc = "Change To Stash Register" }
)
vim.keymap.set(
  "n",
  "C",
  '"' .. stash .. "C",
  { noremap = true, silent = true, desc = "Change Line Tail To Stash Register" }
)

vim.keymap.set({ "n", "x" }, "x", [["_x]], { noremap = true, silent = true, desc = "Delete Char To Black Hole" })
vim.keymap.set("n", "X", [["_X]], { noremap = true, silent = true, desc = "Delete Previous Char To Black Hole" })
vim.keymap.set({ "n", "x" }, "s", '"' .. stash .. "s", { noremap = true, silent = true })
vim.keymap.set("n", "S", '"' .. stash .. "S", { noremap = true, silent = true })

vim.opt.statuscolumn = "%{v:lnum}%s %{v:relnum}"

-- =========================================================================
-- MAYA LINUX NATIVE CODE SENDER
-- =========================================================================
local function send_to_maya(is_visual)
  local lines = {}
  if is_visual then
    local v_pos = vim.fn.getpos("v")
    local cur_pos = vim.fn.getpos(".")
    local start_row = math.min(v_pos[2], cur_pos[2])
    local end_row = math.max(v_pos[2], cur_pos[2])
    lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
  else
    lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end

  local code = table.concat(lines, "\n")
  if code == "" then
    vim.notify("No code to send to Maya!", vim.log.levels.WARN)
    return
  end

  -- Standard Linux temp paths
  local code_path = "/tmp/nvim_maya_temp.py"
  local boot_path = "/tmp/nvim_maya_boot.py"

  -- Write the actual code file
  local code_file = io.open(code_path, "w")
  if not code_file then
    vim.notify("Error: Cannot write to " .. code_path, vim.log.levels.ERROR)
    return
  end
  code_file:write(code)
  code_file:close()

  -- Write the bootstrap wrapper that safely exec's the code file
  local bootstrap = string.format(
    "import __main__, traceback\n"
      .. "try:\n"
      .. "    exec(open(r'%s').read(), __main__.__dict__, __main__.__dict__)\n"
      .. "except Exception:\n"
      .. "    traceback.print_exc()\n",
    code_path
  )
  local boot_file = io.open(boot_path, "w")
  if not boot_file then
    vim.notify("Error: Cannot write to " .. boot_path, vim.log.levels.ERROR)
    return
  end
  boot_file:write(bootstrap)
  boot_file:close()

  -- MEL command just runs the bootstrap
  local exec_cmd = string.format("python(\"exec(open(r'%s').read())\");", boot_path)

  -- Pure Linux: Maya is on localhost
  local host_ip = "127.0.0.1"

  -- Open a TCP socket to Maya
  local uv = vim.uv or vim.loop
  local tcp = uv.new_tcp()

  vim.notify("Connecting to Maya at " .. host_ip .. "...", vim.log.levels.INFO)

  tcp:connect(host_ip, 7001, function(conn_err)
    if conn_err then
      vim.schedule(function()
        vim.notify(
          "Connection failed (" .. host_ip .. ":7001)\n" .. "Is Maya running with commandPort open?",
          vim.log.levels.ERROR
        )
      end)
      tcp:close()
      return
    end

    tcp:write(exec_cmd .. "\n", function(write_err)
      if write_err then
        vim.schedule(function()
          vim.notify("Write failed: " .. write_err, vim.log.levels.ERROR)
        end)
        tcp:close()
        return
      end

      -- Graceful shutdown: sends FIN so Maya fully drains the buffer
      tcp:shutdown(function()
        tcp:close()
        vim.schedule(function()
          vim.notify("Code sent to Maya!", vim.log.levels.INFO)
        end)
      end)
    end)
  end)
end

-- =========================================================================
-- KEYBINDS
-- =========================================================================
-- Normal mode: send entire file
vim.keymap.set("n", "<M-E>", function()
  send_to_maya(false)
end, { noremap = true, desc = "Send entire file to Maya" })

-- Visual mode: send selection (stays in visual mode)
vim.keymap.set("v", "<M-E>", function()
  send_to_maya(true)
end, { noremap = true, desc = "Send selection to Maya" })
