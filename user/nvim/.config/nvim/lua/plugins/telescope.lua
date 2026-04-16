return {
  {
    "nvim-telescope/telescope.nvim",
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
