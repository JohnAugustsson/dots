local uv = vim.uv or vim.loop

local M = {}

M.state = {
  recent = {},
}

M.opts = {
  enabled = true,
  debug = false,
  keep_recent = 8,
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
  return real:gsub("/+", "/")
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
  if not vim.bo[bufnr].buflisted then
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

local function get_alternate_buf()
  local alt = vim.fn.bufnr("#")
  if type(alt) == "number" and alt > 0 and vim.api.nvim_buf_is_valid(alt) then
    return alt
  end
  return nil
end

local function get_harpoon_paths()
  local ok, harpoon = pcall(require, "harpoon")
  if not ok or type(harpoon) ~= "table" or type(harpoon.list) ~= "function" then
    return {}
  end

  local ok_list, list = pcall(function()
    return harpoon:list()
  end)
  if not ok_list or type(list) ~= "table" or type(list.items) ~= "table" then
    return {}
  end

  local paths = {}
  for _, item in ipairs(list.items) do
    if type(item) == "table" and type(item.value) == "string" then
      local path = normalize_path(item.value)
      if path then
        paths[path] = true
      end
    end
  end
  return paths
end

local function is_harpoon_buffer(bufnr)
  local path = normalize_path(buf_name(bufnr))
  if not path then
    return false
  end
  return get_harpoon_paths()[path] == true
end

local function push_recent(bufnr)
  if not is_normal_file_buffer(bufnr) then
    return
  end

  local recent = {}
  table.insert(recent, bufnr)
  for _, existing in ipairs(M.state.recent) do
    if existing ~= bufnr and vim.api.nvim_buf_is_valid(existing) then
      table.insert(recent, existing)
    end
    if #recent >= M.opts.keep_recent then
      break
    end
  end
  M.state.recent = recent
end

local function get_grace_buf(current, alternate)
  for _, bufnr in ipairs(M.state.recent) do
    if bufnr ~= current and bufnr ~= alternate and vim.api.nvim_buf_is_valid(bufnr) and is_normal_file_buffer(bufnr) then
      return bufnr
    end
  end
  return nil
end

local function protected_buffers(leaving_bufnr)
  local protected = {}
  local current = vim.api.nvim_get_current_buf()
  protected[current] = true

  local alternate = get_alternate_buf()
  if alternate and alternate ~= leaving_bufnr then
    protected[alternate] = true
  end

  local grace = get_grace_buf(current, alternate)
  if grace then
    protected[grace] = true
  end

  for bufnr = 1, vim.fn.bufnr("$") do
    if vim.api.nvim_buf_is_valid(bufnr) and is_buffer_visible(bufnr) then
      protected[bufnr] = true
    end
  end

  return protected
end

local function should_delete_buffer(bufnr, protected)
  if not is_normal_file_buffer(bufnr) then
    return false, "not-normal"
  end
  if protected[bufnr] then
    return false, "protected"
  end
  if vim.bo[bufnr].modified then
    return false, "modified"
  end
  if is_harpoon_buffer(bufnr) then
    return false, "harpoon"
  end
  return true, "eligible"
end

function M.cleanup_once(bufnr)
  if not M.opts.enabled or type(bufnr) ~= "number" or bufnr <= 0 then
    return
  end
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local protected = protected_buffers(bufnr)
  local ok_delete, reason = should_delete_buffer(bufnr, protected)
  if not ok_delete then
    notify(string.format("buffer_cleanup keep %d (%s)", bufnr, reason))
    return
  end

  local protected_now = protected_buffers(bufnr)
  local ok_delete_now, reason_now = should_delete_buffer(bufnr, protected_now)
  if not ok_delete_now then
    notify(string.format("buffer_cleanup keep %d (%s)", bufnr, reason_now))
    return
  end

  notify(string.format("buffer_cleanup bdelete %d", bufnr))
  pcall(vim.cmd, string.format("silent! bdelete %d", bufnr))
end

function M.on_buf_leave(bufnr)
  if not M.opts.enabled then
    return
  end
  push_recent(bufnr)
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
M._get_harpoon_paths = get_harpoon_paths
M._is_harpoon_buffer = is_harpoon_buffer
M._get_alternate_buf = get_alternate_buf
M._push_recent = push_recent
M._get_grace_buf = get_grace_buf
M._protected_buffers = protected_buffers
M._should_delete_buffer = should_delete_buffer

return M
