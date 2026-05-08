local uv = vim.uv or vim.loop

local M = {}

M.opts = {
  enabled = true,
  debug = false,
}

local project_markers = {
  ".project-root",
  ".git",
  ".jj",
  "package.json",
  "pyproject.toml",
  "Cargo.toml",
  "Makefile",
}

local function notify(msg, level)
  if M.opts.debug then
    vim.notify(msg, level or vim.log.levels.DEBUG)
  end
end

local function normalize_path(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end
  local expanded = vim.fn.fnamemodify(path, ":p")
  if expanded == "" then
    return nil
  end
  local real = uv.fs_realpath(expanded) or expanded
  return real:gsub("/+", "/"):gsub("/$", "")
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

  local path = normalize_path(name)
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

local function is_inside(path, root)
  if not path or not root then
    return false
  end
  return path == root or path:sub(1, #root + 1) == root .. "/"
end

local function find_project_root(start_path)
  local path = normalize_path(start_path)
  if not path then
    return nil
  end

  local stat = uv.fs_stat(path)
  local dir = stat and stat.type == "directory" and path or vim.fn.fnamemodify(path, ":h")

  while dir and dir ~= "" and dir ~= "/" do
    for _, marker in ipairs(project_markers) do
      if uv.fs_stat(dir .. "/" .. marker) then
        return normalize_path(dir)
      end
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      break
    end
    dir = parent
  end

  return nil
end

local function current_scope_root()
  local cwd = normalize_path(vim.fn.getcwd())

  local ok_project, project_mod = pcall(require, "project_nvim.project")
  if ok_project and type(project_mod.get_project_root) == "function" then
    local ok, root = pcall(project_mod.get_project_root)
    root = ok and normalize_path(root) or nil
    if root then
      return root, "project.nvim"
    end
  end

  local current = normalize_path(buf_name(vim.api.nvim_get_current_buf()))
  local root = find_project_root(current) or find_project_root(cwd)
  if root then
    return root, "marker"
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

  local path = normalize_path(buf_name(bufnr))
  if is_inside(path, scope_root) then
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

M._normalize_path = normalize_path
M._is_normal_file_buffer = is_normal_file_buffer
M._is_buffer_visible = is_buffer_visible
M._find_project_root = find_project_root
M._current_scope_root = current_scope_root
M._should_delete_buffer = should_delete_buffer

return M
