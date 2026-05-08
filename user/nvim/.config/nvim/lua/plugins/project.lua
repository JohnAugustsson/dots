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
      detection_methods = { "lsp", "pattern" },
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
