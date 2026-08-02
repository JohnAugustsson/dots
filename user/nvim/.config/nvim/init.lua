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
local function dedent_lines(lines)
  local tabstop = vim.bo.tabstop
  local indent_columns = {}
  local min_indent

  for i, line in ipairs(lines) do
    if line:find("%S") then
      local whitespace = line:match("^[ \t]*") or ""
      local columns = 0

      for j = 1, #whitespace do
        if whitespace:sub(j, j) == "\t" then
          columns = columns + (tabstop - (columns % tabstop))
        else
          columns = columns + 1
        end
      end

      indent_columns[i] = columns
      min_indent = min_indent and math.min(min_indent, columns) or columns
    end
  end

  if not min_indent or min_indent == 0 then
    return lines
  end

  for i, line in ipairs(lines) do
    if line:find("%S") then
      local content = line:gsub("^[ \t]*", "", 1)
      lines[i] = string.rep(" ", indent_columns[i] - min_indent) .. content
    else
      lines[i] = ""
    end
  end

  return lines
end

local function send_to_maya(is_visual)
  local lines = {}

  if is_visual then
    lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), {
      type = vim.fn.mode(),
      exclusive = false,
    })

    lines = dedent_lines(lines)
  else
    lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end

  local code = table.concat(lines, "\n")

  if code:match("^%s*$") then
    vim.notify("No code to send to Maya!", vim.log.levels.WARN)
    return
  end

  -- Rest of your function remains unchanged.

  -- Standard Linux temp paths
  local code_path = "/tmp/nvim_maya_temp.py"
  local boot_path = "/tmp/nvim_maya_boot.py"
  local output_path = "/tmp/nvim_maya_output.log"

  -- Write the selected/full code
  local code_file = io.open(code_path, "w")
  if not code_file then
    vim.notify("Cannot write to " .. code_path, vim.log.levels.ERROR)
    return
  end

  code_file:write(code)
  code_file:close()

  -- Execute like an interactive Python cell:
  --   * stdout/stderr appear in Maya and the external log
  --   * the final bare expression is displayed using repr()
  --   * definitions/imports remain in Maya's __main__ namespace
  local bootstrap = string.format(
    [=[
import __main__
import ast
import contextlib
import sys
import traceback


class _NvimMayaTee:
    def __init__(self, maya_stream, log_stream):
        self._maya_stream = maya_stream
        self._log_stream = log_stream

    def write(self, text):
        if not isinstance(text, str):
            text = str(text)

        self._maya_stream.write(text)
        self._log_stream.write(text)
        self._log_stream.flush()
        return len(text)

    def flush(self):
        self._maya_stream.flush()
        self._log_stream.flush()

    def __getattr__(self, name):
        return getattr(self._maya_stream, name)


def _nvim_maya_run(code_path, output_path):
    namespace = __main__.__dict__

    # Temporary global used by the transformed final expression
    hook_name = "__nvim_maya_displayhook_7f43c1__"
    missing = object()
    previous_hook = namespace.get(hook_name, missing)
    namespace[hook_name] = sys.__displayhook__

    try:
        with open(output_path, "a", encoding="utf-8", buffering=1) as log:
            log.write("\n--- Maya send ---\n")

            stdout_tee = _NvimMayaTee(sys.stdout, log)
            stderr_tee = _NvimMayaTee(sys.stderr, log)

            with contextlib.redirect_stdout(stdout_tee), contextlib.redirect_stderr(stderr_tee):
                try:
                    with open(code_path, "r", encoding="utf-8") as source_file:
                        source = source_file.read()

                    tree = ast.parse(source, filename=code_path, mode="exec")

                    # Turn the final bare expression into:
                    # sys.displayhook(expression)
                    #
                    # This prints repr(result), suppresses None and updates "_",
                    # matching normal interactive Python behaviour.
                    if tree.body and isinstance(tree.body[-1], ast.Expr):
                        last = tree.body[-1]

                        replacement = ast.Expr(
                            value=ast.Call(
                                func=ast.Name(id=hook_name, ctx=ast.Load()),
                                args=[last.value],
                                keywords=[],
                            )
                        )

                        tree.body[-1] = ast.copy_location(replacement, last)
                        ast.fix_missing_locations(tree)

                    exec(
                        compile(tree, code_path, "exec"),
                        namespace,
                        namespace,
                    )

                except BaseException:
                    traceback.print_exc()

    finally:
        if previous_hook is missing:
            namespace.pop(hook_name, None)
        else:
            namespace[hook_name] = previous_hook


_nvim_maya_run(r"%s", r"%s")
]=],
    code_path,
    output_path
  )

  local boot_file = io.open(boot_path, "w")
  if not boot_file then
    vim.notify("Cannot write to " .. boot_path, vim.log.levels.ERROR)
    return
  end

  boot_file:write(bootstrap)
  boot_file:close()

  -- Keep using the MEL command port
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
vim.keymap.set("x", "<M-E>", function()
  send_to_maya(true)
end, { noremap = true, desc = "Send selection to Maya" })
