local picker = require("config.project_picker")

return {
  {
    "ahmedkhalf/project.nvim",
    config = function(_, opts)
      require("project_nvim").setup(opts)
    end,
    keys = {
      {
        "<leader>fp",
        picker.pick_projects_only,
        desc = "Projects",
      },
      {
        "<C-f>",
        picker.pick_root_entries,
        desc = "Project Root Search",
        mode = "n",
      },
    },
    opts = {
      manual_mode = false,
      -- 'lsp' is deliberately absent. It resolves the root from the attached client's
      -- root_dir (clangd walks up to .git), which disagreed with the '.project-root'
      -- marker below. With manual_mode = false both this plugin and
      -- config.project_picker chdir on BufReadPost, so any disagreement makes them
      -- fight each other in an endless session-switch loop. Pattern only = one rule.
      detection_methods = { "pattern" },
      patterns = {
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
