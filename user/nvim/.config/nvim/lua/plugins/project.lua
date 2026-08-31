return {
  {
    "ahmedkhalf/project.nvim",
    lazy = false,
    config = function(_, opts)
      require("project_nvim").setup(opts)
    end,
    opts = {
      -- project_picker owns cwd/session transitions; automatic BufEnter chdir
      -- would race its source-session save.
      manual_mode = true,
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
