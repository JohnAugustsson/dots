return {
  {
    "ahmedkhalf/project.nvim",
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
      show_hidden = false,
      silent_chdir = true,
      scope_chdir = "global",
    },
  },
}
