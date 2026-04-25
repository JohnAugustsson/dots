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

local function pick_projects_only()
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

    set_project_cwd(choice.path)
    browse_project_files(choice.path)
  end)
end

local function pick_root_entries()
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

    if choice.kind == "file" then
      vim.cmd.edit(vim.fn.fnameescape(choice.path))
    else
      browse_project_files(choice.path)
    end
  end)
end

return {
  {
    "ahmedkhalf/project.nvim",
    config = function(_, opts)
      require("project_nvim").setup(opts)
    end,
    keys = {
      {
        "<leader>fp",
        pick_projects_only,
        desc = "Projects",
      },
      {
        "<C-f>",
        pick_root_entries,
        desc = "Project Root Search",
        mode = "n",
      },
    },
    opts = {
      manual_mode = false,
      detection_methods = { "lsp", "pattern" },
      patterns = {
        ".git",
        ".jj",
        "package.json",
        "pyproject.toml",
        "Cargo.toml",
        "Makefile",
        ".project-root",
      },
      exclude_dirs = {
        "~/Downloads/*",
        "~/.local/*",
        "~/.cache/*",
      },
      show_hidden = true,
      silent_chdir = true,
      scope_chdir = "global",
    },
  },
}
