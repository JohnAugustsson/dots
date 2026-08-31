local M = {}

local paths = require("config.project_paths")
local uv = vim.uv or vim.loop

M.opts = {
  enabled = true,
  debug = false,
}

local function notify(msg, level)
  if M.opts.debug then
    vim.notify(msg, level or vim.log.levels.DEBUG)
  end
end

local function buf_name(bufnr)
  local ok, name = pcall(vim.api.nvim_buf_get_name, bufnr)
  if not ok then
    return ""
  end
  return name
end

local function is_normal_file_buffer(bufnr)
  if type(bufnr) ~= "number" or bufnr <= 0 then
    return false
  end
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  if vim.bo[bufnr].buftype ~= "" then
    return false
  end

  local name = buf_name(bufnr)
  if name == "" then
    return false
  end

  local path = paths.normalize(name)
  if not path then
    return false
  end

  local stat = uv.fs_stat(path)
  if stat and stat.type == "directory" then
    return false
  end

  return true
end

local function is_buffer_visible(bufnr)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
      return true
    end
  end
  return false
end

local function current_scope_root()
  local cwd = paths.normalize(vim.fn.getcwd())
  local root = paths.find_root(cwd)
  if root then
    return root, "cwd-marker"
  end

  return cwd, "cwd"
end

local function should_delete_buffer(bufnr, scope_root)
  if not is_normal_file_buffer(bufnr) then
    return false, "not-normal"
  end
  if vim.bo[bufnr].modified then
    return false, "modified"
  end
  if is_buffer_visible(bufnr) then
    return false, "visible"
  end

  local path = paths.normalize(buf_name(bufnr))
  if paths.is_inside(path, scope_root) then
    return false, "inside-scope"
  end

  return true, "outside-scope"
end

function M.cleanup_once(bufnr)
  if not M.opts.enabled or type(bufnr) ~= "number" or bufnr <= 0 then
    return
  end
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local scope_root, source = current_scope_root()
  local ok_delete, reason = should_delete_buffer(bufnr, scope_root)
  if not ok_delete then
    notify(string.format("buffer_cleanup keep %d (%s, scope=%s)", bufnr, reason, source))
    return
  end

  notify(string.format("buffer_cleanup bdelete %d (%s, scope=%s)", bufnr, reason, source))
  pcall(vim.cmd, string.format("silent! bdelete %d", bufnr))
end

function M.cleanup_all_outside_scope()
  local scope_root = current_scope_root()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local ok_delete = should_delete_buffer(bufnr, scope_root)
      if ok_delete then
        pcall(vim.cmd, string.format("silent! bdelete %d", bufnr))
      end
    end
  end
end

function M.on_buf_leave(bufnr)
  if not M.opts.enabled then
    return
  end
  vim.schedule(function()
    M.cleanup_once(bufnr)
  end)
end

function M.setup(opts)
  if opts then
    M.opts = vim.tbl_deep_extend("force", M.opts, opts)
  end

  local group = vim.api.nvim_create_augroup("ja_buffer_cleanup", { clear = true })
  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function(ev)
      M.on_buf_leave(ev.buf)
    end,
  })
end

M._normalize_path = paths.normalize
M._is_normal_file_buffer = is_normal_file_buffer
M._is_buffer_visible = is_buffer_visible
M._find_project_root = paths.find_root
M._current_scope_root = current_scope_root
M._should_delete_buffer = should_delete_buffer

return M
