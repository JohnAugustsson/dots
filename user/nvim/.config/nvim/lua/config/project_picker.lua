local M = {}

local uv = vim.uv or vim.loop

local project_markers = {
  ".project-root",
  ".git",
  ".jj",
  "package.json",
  "pyproject.toml",
  "Cargo.toml",
  "Makefile",
}

M._switching_project = false

local function load_picker_items(args)
  local helper = vim.fn.expand("~/.config/project-root-picker/scripts/project_root_picker.py")
  local cmd = { helper }
  vim.list_extend(cmd, args or {})
  local lines = vim.fn.systemlist(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("project-root picker failed", vim.log.levels.ERROR)
    return nil
  end

  local items = {}
  local max_width = 0
  for _, line in ipairs(lines) do
    local project, rel_path, path, kind = line:match("([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)")
    if project and path and kind then
      max_width = math.max(max_width, #project)
      table.insert(items, {
        project = project,
        rel_path = rel_path,
        path = path,
        kind = kind,
      })
    end
  end

  if #items == 0 then
    return nil
  end

  return items, max_width
end

local icons = {
  root = "",
  dir = "",
  file = "",
}

local function format_item(max_width)
  return function(item)
    return string.format("%-" .. max_width .. "s  %s  %s", item.project, icons[item.kind] or "?", item.rel_path)
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

local function is_inside(path, root)
  if not path or not root then
    return false
  end
  return path == root or path:sub(1, #root + 1) == root .. "/"
end

local function load_saved_roots()
  local roots_file = vim.fn.expand("~/.config/project-root-picker/project-roots")
  local roots = {}
  if vim.fn.filereadable(roots_file) == 0 then
    return roots
  end

  for _, line in ipairs(vim.fn.readfile(roots_file)) do
    local root = normalize_path(vim.trim(line))
    if root and uv.fs_stat(root) then
      table.insert(roots, root)
    end
  end

  table.sort(roots, function(a, b)
    return #a > #b
  end)
  return roots
end

local function is_inside_saved_root(path)
  for _, root in ipairs(load_saved_roots()) do
    if is_inside(path, root) then
      return true
    end
  end
  return false
end

local function find_project_root(start_path)
  local path = normalize_path(start_path)
  if not path or not is_inside_saved_root(path) then
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

local function current_project_root()
  local current_file = normalize_path(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()))
  return find_project_root(current_file) or find_project_root(vim.fn.getcwd())
end

local function cwd_project_root()
  return find_project_root(vim.fn.getcwd())
end

local function browse_project_files(path)
  local ok_snacks, snacks = pcall(require, "snacks")
  if ok_snacks and snacks.picker and snacks.picker.files then
    snacks.picker.files({ cwd = path, hidden = true })
  else
    vim.notify("Changed cwd to " .. path)
  end
end

local function set_project_cwd(path)
  local ok_project, project_mod = pcall(require, "project_nvim.project")
  if ok_project then
    project_mod.set_pwd(path, "project-root picker")
  else
    vim.api.nvim_set_current_dir(path)
  end
end

local function can_replace_current_session()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr)
      and vim.bo[bufnr].buflisted
      and vim.bo[bufnr].buftype == ""
      and vim.bo[bufnr].modified
    then
      return false
    end
  end
  return true
end

local function clear_arglist()
  vim.cmd("silent! %argdel")
end

local function is_buffer_visible(bufnr)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
      return true
    end
  end
  return false
end

local function wipe_stale_project_buffers()
  local scope = current_project_root() or normalize_path(vim.fn.getcwd())
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" and not vim.bo[bufnr].modified then
      local name = vim.api.nvim_buf_get_name(bufnr)
      local path = normalize_path(name)
      if path and not is_buffer_visible(bufnr) and not is_inside(path, scope) then
        pcall(vim.cmd, "silent! bdelete " .. bufnr)
      end
    end
  end
end

local function reset_current_session_state()
  vim.cmd("silent! tabonly")
  vim.cmd("silent! only")
  vim.cmd("silent! %bwipeout!")
  vim.cmd("silent! enew")
end

local function save_current_project_session()
  local ok_persistence, persistence = pcall(require, "persistence")
  if not ok_persistence then
    return false
  end
  clear_arglist()
  wipe_stale_project_buffers()
  persistence.save()
  return true
end

local function restore_project_session()
  local ok_persistence, persistence = pcall(require, "persistence")
  if not ok_persistence then
    return false
  end

  local session = persistence.current()
  if vim.fn.filereadable(session) == 0 then
    session = persistence.current({ branch = false })
  end
  if vim.fn.filereadable(session) == 0 then
    return false
  end

  clear_arglist()
  reset_current_session_state()
  persistence.load()
  return true
end

local function switch_to_project(path, opts)
  opts = opts or {}
  local project_root = find_project_root(path) or normalize_path(path)
  if not project_root then
    return false
  end

  local current_root = cwd_project_root() or normalize_path(vim.fn.getcwd())
  if current_root == project_root or normalize_path(vim.fn.getcwd()) == project_root then
    return true
  end

  if not can_replace_current_session() then
    vim.notify("Save or close modified buffers before switching project sessions", vim.log.levels.WARN)
    return false
  end

  M._switching_project = true
  save_current_project_session()
  set_project_cwd(project_root)
  local restored = restore_project_session()
  if not restored and not opts.silent_no_session then
    browse_project_files(project_root)
  end
  M._switching_project = false
  return true
end

local function open_project_entry(path)
  if switch_to_project(path) then
    return
  end
end

function M.open_project_file(path)
  path = normalize_path(path)
  if not path then
    return false
  end

  local project_root = find_project_root(path)
  if not project_root then
    return false
  end

  local switched = switch_to_project(project_root, { silent_no_session = true })
  if not switched then
    return false
  end

  vim.cmd.edit(vim.fn.fnameescape(path))
  return true
end

function M.maybe_switch_to_file_project(path)
  if M._switching_project then
    return
  end
  path = normalize_path(path)
  local project_root = find_project_root(path)
  if not project_root then
    return
  end

  local current_root = cwd_project_root() or normalize_path(vim.fn.getcwd())
  if current_root == project_root or normalize_path(vim.fn.getcwd()) == project_root then
    return
  end

  vim.schedule(function()
    if M._switching_project then
      return
    end
    M.open_project_file(path)
  end)
end

function M.pick_projects_only()
  local items, max_width = load_picker_items({ "--projects-only", "--plain" })
  if not items then
    vim.notify("No projects found from project-root picker", vim.log.levels.WARN)
    return
  end

  vim.ui.select(items, {
    prompt = "Projects",
    format_item = format_item(max_width),
  }, function(choice)
    if not choice then
      return
    end

    open_project_entry(choice.path)
  end)
end

function M.pick_root_entries()
  local items, max_width = load_picker_items({ "--plain" })
  if not items then
    vim.notify("No entries found from project-root picker", vim.log.levels.WARN)
    return
  end

  vim.ui.select(items, {
    prompt = "Project Root Search",
    format_item = format_item(max_width),
  }, function(choice)
    if not choice then
      return
    end

    if choice.kind == "root" and choice.rel_path == "./" then
      open_project_entry(choice.path)
    elseif choice.kind == "file" then
      M.open_project_file(choice.path)
    else
      browse_project_files(choice.path)
    end
  end)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("ja_project_session_switch", { clear = true })
  local function maybe_switch_buf(bufnr)
    if vim.bo[bufnr].buftype ~= "" then
      return
    end
    M.maybe_switch_to_file_project(vim.api.nvim_buf_get_name(bufnr))
  end

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = group,
    callback = function(ev)
      maybe_switch_buf(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    callback = function()
      maybe_switch_buf(vim.api.nvim_get_current_buf())
    end,
  })
end

M._normalize_path = normalize_path
M._find_project_root = find_project_root
M._current_project_root = current_project_root
M._load_saved_roots = load_saved_roots

return M
