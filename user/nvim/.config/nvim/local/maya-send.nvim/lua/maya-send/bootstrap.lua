local M = {}

local RUNNER = "python/maya_runner.py"

-- A Python string literal, so paths keep their backslashes and quotes.
local function py_string(value)
  return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

local cached_runner

function M.runner_path()
  return vim.api.nvim_get_runtime_file(RUNNER, false)[1]
end

function M.runner_source()
  if cached_runner then
    return cached_runner
  end

  local path = M.runner_path()
  if not path then
    return nil, RUNNER .. " not found on the runtimepath"
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil, "cannot read " .. path
  end

  cached_runner = table.concat(lines, "\n")
  return cached_runner
end

-- The code Maya executes: the runner definitions plus the call that runs the
-- snippet Neovim just wrote out.
function M.render(code_path, output_path)
  local source, err = M.runner_source()
  if not source then
    return nil, err
  end

  return string.format("%s\n\n_nvim_maya_run(%s, %s)\n", source, py_string(code_path), py_string(output_path))
end

return M
