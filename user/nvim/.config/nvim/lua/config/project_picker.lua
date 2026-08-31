local M = {}

local paths = require("config.project_paths")
local uv = vim.uv or vim.loop

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

local normalize_path = paths.normalize

local function load_saved_roots()
  return paths.load_saved_roots()
end

local function find_project_root(start_path)
  return paths.find_root(start_path, { require_saved_root = true })
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
    -- The reset below wipes every buffer number, including unlisted and
    -- special buffers. Refuse the switch if one carries changes or owns a
    -- running terminal job.
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].modified then
      return false, "modified buffer"
    end
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "terminal" then
      local job_id = vim.b[bufnr].terminal_job_id
      if type(job_id) ~= "number" then
        return false, "terminal buffer"
      end
      local ok, status = pcall(vim.fn.jobwait, { job_id }, 0)
      if not ok or type(status) ~= "table" or status[1] == -1 then
        return false, "running terminal"
      end
    end
  end
  return true
end

local function clear_arglist()
  vim.cmd("silent! %argdel")
end

local function buffer_is_in_root(bufnr, root)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" then
    return false
  end
  local path = normalize_path(vim.api.nvim_buf_get_name(bufnr))
  return path ~= nil and paths.is_inside(path, root)
end

local function source_fallback_buffer(source_root, excluded)
  local alternate = vim.fn.bufnr("#")
  if alternate > 0 and not excluded[alternate] and buffer_is_in_root(alternate, source_root) then
    return alternate, false
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if not excluded[bufnr] and buffer_is_in_root(bufnr, source_root) then
      return bufnr, false
    end
  end

  return vim.api.nvim_create_buf(true, false), true
end

---Keep destination buffers out of the source session. This is needed for
---BufReadPost/BufNewFile switches, where the destination file is already in a
---window by the time the scheduled switch runs.
local function without_destination_buffers_in_session(source_root, destination_root, callback)
  local excluded = {}
  local listed = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if buffer_is_in_root(bufnr, destination_root) then
      excluded[bufnr] = true
      listed[bufnr] = vim.bo[bufnr].buflisted
    end
  end

  local window_buffers = {}
  local fallback
  local created_fallback = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local bufnr = vim.api.nvim_win_get_buf(win)
      if excluded[bufnr] then
        if not fallback then
          fallback, created_fallback = source_fallback_buffer(source_root, excluded)
        end
        window_buffers[win] = bufnr
        vim.api.nvim_win_set_buf(win, fallback)
      end
    end
  end

  for bufnr in pairs(excluded) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.bo[bufnr].buflisted = false
    end
  end

  local ok, result = xpcall(callback, debug.traceback)

  for bufnr, was_listed in pairs(listed) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.bo[bufnr].buflisted = was_listed
    end
  end
  for win, bufnr in pairs(window_buffers) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_win_set_buf(win, bufnr)
    end
  end
  if created_fallback and fallback and vim.api.nvim_buf_is_valid(fallback) then
    pcall(vim.api.nvim_buf_delete, fallback, { force = true })
  end

  if not ok then
    error(result, 0)
  end
  return result
end

local function reset_current_session_state()
  vim.cmd("silent tabonly")
  vim.cmd("silent only")
  vim.cmd("silent %bwipeout")
  vim.cmd("silent enew")
end

local function save_current_project_session(source_root, destination_root)
  local ok_persistence, persistence = pcall(require, "persistence")
  if not ok_persistence then
    return false
  end

  without_destination_buffers_in_session(source_root, destination_root, function()
    clear_arglist()
    persistence.save()
  end)
  return true
end

local function replace_with_project_session()
  local ok_persistence, persistence = pcall(require, "persistence")
  local session
  if ok_persistence then
    session = persistence.current()
    if vim.fn.filereadable(session) == 0 then
      session = persistence.current({ branch = false })
    end
  end

  clear_arglist()
  reset_current_session_state()

  if not ok_persistence or vim.fn.filereadable(session) == 0 then
    return false
  end
  persistence.load()
  return true
end

local function switch_to_project_root(project_root, opts)
  opts = opts or {}
  project_root = normalize_path(project_root)
  if not project_root then
    return false
  end

  local source_cwd = normalize_path(vim.fn.getcwd())
  local source_root = cwd_project_root() or source_cwd
  if source_root == project_root or source_cwd == project_root then
    return true
  end

  local can_replace, blocker = can_replace_current_session()
  if not can_replace then
    vim.notify("Cannot switch project sessions: close the " .. blocker .. " first", vim.log.levels.WARN)
    return false
  end

  M._switching_project = true
  local ok, restored = xpcall(function()
    save_current_project_session(source_root, project_root)
    set_project_cwd(project_root)
    return replace_with_project_session()
  end, debug.traceback)
  M._switching_project = false

  if not ok then
    if source_cwd then
      pcall(vim.api.nvim_set_current_dir, source_cwd)
    end
    vim.notify("Project session switch failed:\n" .. restored, vim.log.levels.ERROR)
    return false
  end

  if not restored and not opts.silent_no_session then
    browse_project_files(project_root)
  end
  return true
end

local function switch_to_project(path, opts)
  local project_root = find_project_root(path) or normalize_path(path)
  if not project_root then
    return false
  end
  return switch_to_project_root(project_root, opts)
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



local function parse_fzf_output(path)
  local result = { mode = nil, state = nil, row = nil }
  if vim.fn.filereadable(path) == 0 then
    return result
  end
  for _, line in ipairs(vim.fn.readfile(path)) do
    local key, value = line:match("^([^\t]+)\t(.*)$")
    if key then
      result[key] = value
    end
  end
  return result
end

local function path_from_row(row)
  if not row or row == "" then
    return nil
  end
  return row:match("^[^\t]*\t(.+)$")
end

local function jump_to_rg_state(state_file, selected_path)
  if not state_file or state_file == "" or vim.fn.filereadable(state_file) == 0 then
    return
  end

  local raw = vim.fn.readfile(state_file)[1]
  if not raw then
    return
  end

  local state_path, query = raw:match("^([^\t]*)\t([^\t]*)\t")
  if not state_path or state_path ~= selected_path or not query or query == "" then
    return
  end

  local helper = vim.fn.expand("~/.config/project-root-picker/scripts/project_root_picker_match.py")
  vim.system({ helper, "current", "--state", state_file, "--query", query, "--path", selected_path }, { text = true }, vim.schedule_wrap(function(result)
    vim.fn.delete(state_file)
    local parts = vim.split(vim.trim(result.stdout or ""), "\t")
    local line = tonumber(parts[1])
    local col = tonumber(parts[2])
    if line and col then
      pcall(vim.api.nvim_win_set_cursor, 0, { line, math.max(col - 1, 0) })
      pcall(vim.cmd, "normal! zz")
    end
  end))
end

local function pick_entries_fzf(scope, title)
  local runner = vim.fn.expand("~/.config/project-root-picker/scripts/project_root_picker_fzf")
  if vim.fn.executable(runner) == 0 or vim.fn.executable("fzf") == 0 then
    return false
  end

  local out_file = vim.fn.tempname()
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.96)
  local height = math.floor(vim.o.lines * 0.9)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = title or "Project Search",
  })

  local files_only = scope == "project" and "files" or "all"
  vim.fn.termopen({ runner, scope, vim.fn.getcwd(), out_file, files_only }, {
    on_exit = vim.schedule_wrap(function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end

      local result = parse_fzf_output(out_file)
      local debug_lines = vim.fn.filereadable(out_file) == 1 and vim.fn.readfile(out_file) or {}
      vim.fn.delete(out_file)
      local selected_path = result.path or path_from_row(result.row)
      if not selected_path or selected_path == "" then
        if #debug_lines > 0 then
          vim.notify("Project picker returned no path. Output: " .. table.concat(debug_lines, " | "), vim.log.levels.WARN)
        end
        return
      end
      selected_path = vim.trim(selected_path)

      local stat = uv.fs_stat(selected_path)
      if result.mode == "rg" then
        if not M.open_project_file(selected_path) and stat and stat.type == "file" then
          vim.cmd.edit(vim.fn.fnameescape(selected_path))
        end
        jump_to_rg_state(result.state, selected_path)
      elseif stat and stat.type == "file" then
        if not M.open_project_file(selected_path) then
          vim.cmd.edit(vim.fn.fnameescape(selected_path))
        end
      elseif stat and stat.type == "directory" then
        if not M.open_project_path(selected_path) then
          browse_project_files(selected_path)
        end
      else
        vim.notify("Selected path does not exist: " .. selected_path, vim.log.levels.WARN)
      end
    end),
  })
  vim.cmd.startinsert()
  return true
end

function M.pick_entries(scope, title)
  scope = scope or "roots"
  title = title or "Project Search"
  if pick_entries_fzf(scope, title) then
    return
  end
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
M._can_replace_current_session = can_replace_current_session
M._switch_to_project_root = switch_to_project_root

return M
