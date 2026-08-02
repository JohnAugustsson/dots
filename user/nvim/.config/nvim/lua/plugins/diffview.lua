-- ~/.config/nvim/lua/plugins/diffview.lua

return {
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },

    opts = {
      enhanced_diff_hl = true,
    },

    keys = {
      {
        "<leader>gv",
        "<cmd>DiffviewOpen<cr>",
        desc = "Git changes",
      },
      {
        "<leader>gV",
        "<cmd>DiffviewOpen origin/master...HEAD<cr>",
        desc = "Branch changes",
      },
      {
        "<leader>gH",
        "<cmd>DiffviewFileHistory %<cr>",
        desc = "Current file history",
      },
      {
        "<leader>gC",
        "<cmd>DiffviewClose<cr>",
        desc = "Close diff view",
      },
    },
  },
}
