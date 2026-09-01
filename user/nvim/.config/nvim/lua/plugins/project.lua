return {
  {
    "JohnAugustsson/project-root-picker",
    lazy = false,
    main = "project_root_picker",
    dependencies = {
      { "folke/persistence.nvim", opts = {} },
    },
    opts = {
      sessions = {
        enabled = true,
        auto_switch = true,
        provider = "persistence",
        browse_on_missing = true,
      },
      cleanup = {
        enabled = true,
      },
    },
  },
}
