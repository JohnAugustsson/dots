return {
  {
    dir = vim.fn.stdpath("config") .. "/local/maya-send.nvim",
    opts = {},
    config = function(_, opts)
      require("maya-send").setup(opts)
    end,
  },
}
