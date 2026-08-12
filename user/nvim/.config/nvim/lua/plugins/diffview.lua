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
        function()
          local main = vim.fn.system("git rev-parse --verify origin/main 2>/dev/null")
          local branch = vim.v.shell_error == 0 and "origin/main" or "origin/master"
          vim.cmd("DiffviewOpen " .. branch .. "...HEAD")
        end,
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
