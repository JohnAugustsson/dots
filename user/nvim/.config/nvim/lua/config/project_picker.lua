local M = {}

local function load_picker_items(args)
  local helper = vim.fn.expand("~/.config/fish/scripts/project_root_picker.py")
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

local function normalize_path(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end
  local expanded = vim.fn.fnamemodify(path, ":p")
  if expanded == "" then
    return nil
  end
  local real = vim.uv.fs_realpath(expanded) or expanded
  return real:gsub("/+", "/")
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
  local cwd = normalize_path(vim.fn.getcwd())
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" and not vim.bo[bufnr].modified then
      local name = vim.api.nvim_buf_get_name(bufnr)
      local path = normalize_path(name)
      if path and not is_buffer_visible(bufnr) then
        local in_project = cwd and (path == cwd or path:sub(1, #cwd + 1) == cwd .. "/")
        if not vim.bo[bufnr].buflisted or not in_project then
          pcall(vim.cmd, "silent! bwipeout " .. bufnr)
        end
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

local function open_project_entry(path)
  if not can_replace_current_session() then
    vim.notify("Save or close modified buffers before switching project sessions", vim.log.levels.WARN)
    return
  end

  save_current_project_session()
  set_project_cwd(path)
  if not restore_project_session() then
    browse_project_files(path)
  end
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
      vim.cmd.edit(vim.fn.fnameescape(choice.path))
    else
      browse_project_files(choice.path)
    end
  end)
end

return M
