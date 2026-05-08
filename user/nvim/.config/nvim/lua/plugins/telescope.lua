local function live_grep_current_project()
  local builtin = require("telescope.builtin")
  local project = require("config.project_picker")
  local cwd = project._current_project_root() or vim.fn.getcwd()
  builtin.live_grep({ cwd = cwd, prompt_title = "Live Grep Current Project" })
end

local function live_grep_all_projects()
  local builtin = require("telescope.builtin")
  local project = require("config.project_picker")
  local roots = project._load_saved_roots()
  if #roots == 0 then
    vim.notify("No project roots configured. Use: project-root", vim.log.levels.WARN)
    return
  end
  builtin.live_grep({ search_dirs = roots, prompt_title = "Live Grep All Projects" })
end

local function live_grep_home()
  require("telescope.builtin").live_grep({ cwd = vim.fn.expand("~"), prompt_title = "Live Grep ~" })
end

local function live_grep_global()
  require("telescope.builtin").live_grep({ cwd = "/", prompt_title = "Live Grep /" })
end

return {
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      { "<leader>fg", live_grep_current_project, desc = "Grep Current Project" },
      { "<leader>fG", live_grep_all_projects, desc = "Grep All Projects" },
      { "<leader>fh", live_grep_home, desc = "Grep Home" },
      { "<leader>fH", live_grep_global, desc = "Grep Global" },
    },
    opts = {
      extensions = {
        project = {
          hidden_files = true,
        },
      },
      pickers = {
        find_files = {
          hidden = true,
        },
      },
    },
  },
}
