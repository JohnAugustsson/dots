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

local picker_hl = {
  project = "ProjectRootPickerProject",
  root = "ProjectRootPickerRoot",
  dir = "ProjectRootPickerDir",
  file = "ProjectRootPickerFile",
}

local function ensure_picker_highlights()
  vim.api.nvim_set_hl(0, picker_hl.project, { fg = "#d69098", bold = true })
  vim.api.nvim_set_hl(0, picker_hl.root, { fg = "#f0ddde", bold = true })
  vim.api.nvim_set_hl(0, picker_hl.dir, { fg = "#7a84a3" })
  vim.api.nvim_set_hl(0, picker_hl.file, { fg = "#dec3c4" })
end

local function strip_ansi(value)
  return (value or ""):gsub("\27%[[0-9;?]*[ -/]*[@-~]", "")
end

local ansi_colors = {
  ["30"] = "#000000",
  ["31"] = "#ff5555",
  ["32"] = "#50fa7b",
  ["33"] = "#f1fa8c",
  ["34"] = "#bd93f9",
  ["35"] = "#ff79c6",
  ["36"] = "#8be9fd",
  ["37"] = "#f8f8f2",
  ["90"] = "#6272a4",
  ["91"] = "#ff6e6e",
  ["92"] = "#69ff94",
  ["93"] = "#ffffa5",
  ["94"] = "#d6acff",
  ["95"] = "#ff92df",
  ["96"] = "#a4ffff",
  ["97"] = "#ffffff",
}

local ansi_256 = {
  [139] = "#af87af",
  [144] = "#afaf87",
  [145] = "#afafaf",
  [132] = "#af5f87",
  [174] = "#d78787",
  [244] = "#808080",
  [251] = "#c6c6c6",
}

local function ansi_to_lines_and_highlights(output)
  local lines = {}
  local highlights = {}
  local current_line = {}
  local line_hls = {}
  local col = 0
  local fg = nil
  local bg = nil
  local bold = false
  local i = 1

  local function flush_line()
    table.insert(lines, table.concat(current_line))
    table.insert(highlights, line_hls)
    current_line = {}
    line_hls = {}
    col = 0
  end

  local function current_group()
    if not fg and not bg and not bold then
      return nil
    end
    local name = "ProjectRootPickerAnsi_" .. (fg or "none"):gsub("#", "") .. "_" .. (bg or "none"):gsub("#", "") .. "_" .. tostring(bold)
    if not vim.g[name] then
      vim.api.nvim_set_hl(0, name, { fg = fg, bg = bg, bold = bold })
      vim.g[name] = true
    end
    return name
  end

  local function apply_sgr(params)
    if #params == 0 then
      params = { "0" }
    end
    local idx = 1
    while idx <= #params do
      local p = params[idx]
      if p == "0" then
        fg, bg, bold = nil, nil, false
      elseif p == "1" then
        bold = true
      elseif p == "22" then
        bold = false
      elseif p == "39" then
        fg = nil
      elseif p == "49" then
        bg = nil
      elseif ansi_colors[p] then
        fg = ansi_colors[p]
      elseif tonumber(p) and tonumber(p) >= 40 and tonumber(p) <= 47 then
        bg = ansi_colors[tostring(tonumber(p) - 10)]
      elseif tonumber(p) and tonumber(p) >= 100 and tonumber(p) <= 107 then
        bg = ansi_colors[tostring(tonumber(p) - 10)]
      elseif (p == "38" or p == "48") and params[idx + 1] == "5" and params[idx + 2] then
        local color = ansi_256[tonumber(params[idx + 2])]
        if p == "38" then
          fg = color
        else
          bg = color
        end
        idx = idx + 2
      elseif (p == "38" or p == "48") and params[idx + 1] == "2" and params[idx + 2] and params[idx + 3] and params[idx + 4] then
        local color = string.format("#%02x%02x%02x", tonumber(params[idx + 2]), tonumber(params[idx + 3]), tonumber(params[idx + 4]))
        if p == "38" then
          fg = color
        else
          bg = color
        end
        idx = idx + 4
      end
      idx = idx + 1
    end
  end

  while i <= #output do
    local esc_start, esc_end, code = output:find("\27%[([0-9;]*)m", i)
    local next_newline = output:find("\n", i, true)
    if esc_start and (not next_newline or esc_start < next_newline) then
      if esc_start > i then
        local text = output:sub(i, esc_start - 1)
        local group = current_group()
        table.insert(current_line, text)
        if group then
          table.insert(line_hls, { col, col + #text, group })
        end
        col = col + #text
      end
      apply_sgr(vim.split(code, ";", { plain = true, trimempty = true }))
      i = esc_end + 1
    elseif next_newline then
      if next_newline > i then
        local text = output:sub(i, next_newline - 1)
        local group = current_group()
        table.insert(current_line, text)
        if group then
          table.insert(line_hls, { col, col + #text, group })
        end
      end
      flush_line()
      i = next_newline + 1
    else
      local text = output:sub(i)
      local group = current_group()
      table.insert(current_line, text)
      if group then
        table.insert(line_hls, { col, col + #text, group })
      end
      break
    end
  end

  flush_line()
  return lines, highlights
end

local function stream_display_parts(display)
  local project, icon, rel = display:match("^(.-)%s%s([^%s]+)%s%s(.+)$")
  if not project or not icon or not rel then
    return nil
  end

  local kind = icon == icons.root and "root" or icon == icons.dir and "dir" or "file"
  return project, icon, rel, kind
end

local function make_stream_highlights(display)
  local project, icon, rel, kind = stream_display_parts(display)
  if not project then
    return {}
  end

  local highlights = {}
  local project_start = 0
  local project_end = #project
  local icon_start = project_end + 2
  local icon_end = icon_start + #icon
  local rel_start = icon_end + 2

  table.insert(highlights, { { project_start, project_end }, picker_hl.project })
  table.insert(highlights, { { icon_start, icon_end }, picker_hl[kind] or picker_hl.file })

  if kind == "file" then
    local dir, sep, name = rel:match("^(.*)(/)([^/]*)$")
    if sep then
      local dir_end = rel_start + #dir + #sep
      table.insert(highlights, { { rel_start, dir_end }, picker_hl.dir })
      table.insert(highlights, { { dir_end, dir_end + #name }, picker_hl.file })
    else
      table.insert(highlights, { { rel_start, rel_start + #rel }, picker_hl.file })
    end
  else
    table.insert(highlights, { { rel_start, rel_start + #rel }, picker_hl[kind] or picker_hl.dir })
  end

  return highlights
end

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

local function saved_root_for(path)
  for _, root in ipairs(load_saved_roots()) do
    if is_inside(path, root) then
      return root
    end
  end
  return nil
end

local function is_inside_saved_root(path)
  return saved_root_for(path) ~= nil
end

local function find_project_root(start_path)
  local path = normalize_path(start_path)
  if not path then
    return nil
  end

  local saved_root = saved_root_for(path)
  if not saved_root then
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
    if dir == saved_root then
      break
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      break
    end
    dir = parent
  end

  return saved_root
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

function M.open_project_path(path, opts)
  opts = opts or {}
  path = normalize_path(path)
  if not path then
    return false
  end

  local stat = uv.fs_stat(path)
  if stat and stat.type == "directory" then
    local project_root = find_project_root(path)
    if project_root then
      local switched = switch_to_project(project_root, opts)
      if switched and path ~= project_root and not opts.no_browse then
        browse_project_files(path)
      end
      return switched
    end
    return false
  end

  return M.open_project_file(path)
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

local function left_truncate_display(text, width)
  width = math.max(width or 20, 10)
  if vim.fn.strdisplaywidth(text) <= width then
    return text
  end
  local ellipsis = "…"
  local out = ""
  for _, codepoint in ipairs(vim.fn.reverse(vim.fn.split(text, "\\zs"))) do
    if vim.fn.strdisplaywidth(ellipsis .. codepoint .. out) > width then
      break
    end
    out = codepoint .. out
  end
  return ellipsis .. out
end

local function build_dynamic_display(project, icon, rel, width)
  local prefix_width = vim.fn.strdisplaywidth(project .. "  " .. icon .. "  ")
  local rel_width = math.max(20, (width or 80) - prefix_width - 2)
  return project .. "  " .. icon .. "  " .. left_truncate_display(rel, rel_width)
end

local function make_telescope_entry(line)
  local count = 0
  local count_s, counted_display, counted_path = line:match("^(%d+)\t([^\t]*)\t(.+)$")
  local display, path
  if count_s then
    count = tonumber(count_s) or 0
    display = counted_display
    path = counted_path
  else
    display, path = line:match("^([^\t]*)\t(.+)$")
  end
  if not display or not path then
    return nil
  end

  local clean_display = strip_ansi(display)
  local project, icon, rel = stream_display_parts(clean_display)
  return {
    value = path,
    count = count,
    project = project,
    icon = icon,
    rel = rel,
    display = function(entry)
      local width = math.floor(vim.o.columns * 0.95) - 4
      local display_text = entry.project and build_dynamic_display(entry.project, entry.icon, entry.rel, width) or entry.display_text
      return display_text, make_stream_highlights(display_text)
    end,
    display_text = clean_display,
    highlights = make_stream_highlights(clean_display),
    ordinal = clean_display .. " " .. path,
    path = path,
    filename = path,
  }
end

local function open_telescope_selection(prompt_bufnr)
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local selection = action_state.get_selected_entry()
  actions.close(prompt_bufnr)
  if not selection or not selection.path then
    return
  end

  local path = selection.path
  local stat = uv.fs_stat(path)
  if stat and stat.type == "file" then
    M.open_project_file(path)
    return
  end

  local project_root = find_project_root(path)
  if project_root and path == project_root then
    open_project_entry(path)
  elseif stat and stat.type == "directory" then
    browse_project_files(path)
  else
    M.open_project_path(path)
  end
end

local function file_only_entry_maker(line)
  local entry = make_telescope_entry(line)
  if not entry then
    return nil
  end
  local stat = uv.fs_stat(entry.path)
  if stat and stat.type == "directory" then
    return nil
  end
  return entry
end

local function make_path_finder(scope)
  local finders = require("telescope.finders")
  local entries = vim.fn.expand("~/.config/project-root-picker/scripts/project_root_picker_entries.py")
  return finders.new_oneshot_job({ entries, "path", scope, vim.fn.getcwd() }, {
    entry_maker = scope == "project" and file_only_entry_maker or make_telescope_entry,
  })
end

local function make_rg_finder(scope)
  local finders = require("telescope.finders")
  local helper = vim.fn.expand("~/.config/project-root-picker/scripts/project_root_picker.py")
  return finders.new_job(function(prompt)
    if not prompt or prompt == "" then
      return nil
    end
    return { helper, "--scope", scope, "--start", vim.fn.getcwd(), "--grep", prompt, "--grep-stream" }
  end, make_telescope_entry)
end

local function set_picker_title(picker, title)
  picker.prompt_title = title
  if picker.layout and picker.layout.prompt and picker.layout.prompt.border then
    pcall(picker.layout.prompt.border.change_title, picker.layout.prompt.border, title)
  end
end

local function grep_count_sorter()
  local sorters = require("telescope.sorters")
  return sorters.Sorter:new({
    scoring_function = function(_, _, entry)
      return -(entry.count or 0)
    end,
    highlighter = function()
      return {}
    end,
  })
end

local function pick_entries_telescope(scope, title)
  local ok_pickers, pickers = pcall(require, "telescope.pickers")
  local ok_conf, conf = pcall(require, "telescope.config")
  local ok_actions, actions = pcall(require, "telescope.actions")
  local ok_action_state, action_state = pcall(require, "telescope.actions.state")
  local ok_sorters, sorters = pcall(require, "telescope.sorters")
  local ok_previewers, previewers = pcall(require, "telescope.previewers")
  if not (ok_pickers and ok_conf and ok_actions and ok_action_state and ok_sorters and ok_previewers) then
    return false
  end

  local entries = vim.fn.expand("~/.config/project-root-picker/scripts/project_root_picker_entries.py")
  local preview = vim.fn.expand("~/.config/project-root-picker/scripts/project_root_picker_preview.py")
  local nav = vim.fn.expand("~/.config/project-root-picker/scripts/project_root_picker_match_nav.py")
  local match_helper = vim.fn.expand("~/.config/project-root-picker/scripts/project_root_picker_match.py")
  if vim.fn.executable(entries) == 0 or vim.fn.executable(preview) == 0 or vim.fn.executable(nav) == 0 or vim.fn.executable(match_helper) == 0 then
    return false
  end

  ensure_picker_highlights()

  local mode = "path"
  local state_file = vim.fn.tempname()
  local picker
  picker = pickers.new({}, {
    prompt_title = title or "Project Search",
    layout_strategy = "vertical",
    layout_config = {
      width = 0.95,
      height = 0.95,
      preview_height = 0.6,
      preview_cutoff = 1,
      prompt_position = "bottom",
    },
    finder = make_path_finder(scope),
    sorter = conf.values.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = "Project Preview",
      define_preview = function(self, entry, status)
        if not entry or not entry.path then
          return
        end
        local query = ""
        if mode == "rg" and status and status.picker and status.picker._get_prompt then
          query = status.picker:_get_prompt()
        end
        local cmd = { preview, mode == "rg" and "grep" or "path", query, state_file, entry.path }
        vim.system(cmd, { text = true }, vim.schedule_wrap(function(result)
          if not self.state or not self.state.bufnr or not vim.api.nvim_buf_is_valid(self.state.bufnr) then
            return
          end
          local lines, hls = ansi_to_lines_and_highlights(result.stdout or "")
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
          local ns = vim.api.nvim_create_namespace("project_root_picker_preview")
          vim.api.nvim_buf_clear_namespace(self.state.bufnr, ns, 0, -1)
          for lnum, line_hls in ipairs(hls) do
            for _, hl in ipairs(line_hls) do
              pcall(vim.api.nvim_buf_add_highlight, self.state.bufnr, ns, hl[3], lnum - 1, hl[1], hl[2])
            end
          end
        end))
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      local function current_query()
        local current_picker = action_state.get_current_picker(prompt_bufnr)
        if current_picker and current_picker._get_prompt then
          return current_picker:_get_prompt()
        end
        return ""
      end

      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if not selection or not selection.path then
          actions.close(prompt_bufnr)
          return
        end

        if mode == "rg" then
          local query = current_query()
          vim.system({ match_helper, "current", "--state", state_file, "--query", query, "--path", selection.path }, { text = true }, vim.schedule_wrap(function(result)
            actions.close(prompt_bufnr)
            M.open_project_file(selection.path)
            local parts = vim.split(vim.trim(result.stdout or ""), "	")
            local line = tonumber(parts[1])
            local col = tonumber(parts[2])
            if line and col then
              vim.schedule(function()
                pcall(vim.api.nvim_win_set_cursor, 0, { line, math.max(col - 1, 0) })
                pcall(vim.cmd, "normal! zz")
              end)
            end
          end))
          return
        end

        open_telescope_selection(prompt_bufnr)
      end)

      local function jump_match(delta)
        if mode ~= "rg" then
          return
        end
        local selection = action_state.get_selected_entry()
        if not selection or not selection.path then
          return
        end
        vim.system({ nav, state_file, tostring(delta), current_query(), selection.path }, { text = true }, vim.schedule_wrap(function()
          local current_picker = action_state.get_current_picker(prompt_bufnr)
          if current_picker and current_picker.refresh_previewer then
            current_picker:refresh_previewer()
          end
        end))
      end

      local function toggle_rg()
        local current_picker = action_state.get_current_picker(prompt_bufnr)
        if mode == "path" then
          mode = "rg"
          set_picker_title(current_picker, "grep " .. (title or "Project Search"))
          current_picker.sorter = grep_count_sorter()
          current_picker:refresh(make_rg_finder(scope), { reset_prompt = false })
        else
          mode = "path"
          set_picker_title(current_picker, title or "Project Search")
          current_picker.sorter = conf.values.generic_sorter({})
          current_picker:refresh(make_path_finder(scope), { reset_prompt = false })
        end
      end

      map({ "i", "n" }, "<C-s>", toggle_rg)
      map({ "i", "n" }, "<C-j>", function() jump_match(1) end)
      map({ "i", "n" }, "<C-l>", function() jump_match(1) end)
      map({ "i", "n" }, "<C-k>", function() jump_match(-1) end)
      map({ "i", "n" }, "<C-h>", function() jump_match(-1) end)
      return true
    end,
  })

  picker:find()
  return true
end



function M.pick_entries(scope, title)
  scope = scope or "roots"
  title = title or "Project Search"
  if pick_entries_telescope(scope, title) then
    return
  end

  local args = scope == "roots" and { "--plain" } or { "--scope", scope, "--start", vim.fn.getcwd(), "--plain" }
  local items, max_width = load_picker_items(args)
  if not items then
    vim.notify("No entries found from project-root picker", vim.log.levels.WARN)
    return
  end

  vim.ui.select(items, {
    prompt = title,
    format_item = format_item(max_width),
  }, function(choice)
    if not choice then
      return
    end

    if choice.kind == "root" and choice.rel_path == "./" then
      M.open_project_path(choice.path)
    elseif choice.kind == "file" then
      M.open_project_file(choice.path)
    else
      browse_project_files(choice.path)
    end
  end)
end

function M.pick_root_entries()
  M.pick_entries("roots", "Project Root Search")
end

function M.pick_cwd_entries()
  M.pick_entries("cwd", "Cwd Search")
end

function M.pick_project_entries()
  M.pick_entries("project", "Project Search")
end

function M.pick_home_entries()
  M.pick_entries("home", "Home Search")
end

function M.pick_global_entries()
  M.pick_entries("global", "Global Search")
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
      if vim.fn.argc() > 0 then
        local arg = normalize_path(vim.fn.argv(0))
        local stat = arg and uv.fs_stat(arg)
        if stat and stat.type == "directory" and find_project_root(arg) then
          vim.schedule(function()
            M.open_project_path(arg, { no_browse = true })
          end)
          return
        end
      end

      maybe_switch_buf(vim.api.nvim_get_current_buf())
    end,
  })
end

M._normalize_path = normalize_path
M._find_project_root = find_project_root
M._current_project_root = current_project_root
M._load_saved_roots = load_saved_roots

return M
