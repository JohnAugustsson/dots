return {
  {
    "mikesmithgh/kitty-scrollback.nvim",
    version = "v9.1.0",
    lazy = true,
    cmd = {
      "KittyScrollbackGenerateKittens",
      "KittyScrollbackCheckHealth",
      "KittyScrollbackGenerateCommandLineEditing",
    },
    event = { "User KittyScrollbackLaunch" },
    config = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("UserKittyScrollbackUI", { clear = true }),
        pattern = "kitty-scrollback",
        callback = function()
          vim.opt_local.number = false
          vim.opt_local.relativenumber = false
          vim.opt_local.statuscolumn = ""
          vim.opt_local.signcolumn = "no"
          vim.opt_local.foldcolumn = "0"
        end,
      })

      require("kitty-scrollback").setup({
        keymaps_enabled = false,
        paste_window = {
          yank_register_enabled = false,
        },
        callbacks = {
          after_ready = function()
            vim.schedule(function()
              pcall(vim.api.nvim_del_augroup_by_name, "KittyScrollBackNvimTextYankPost")
            end)
          end,
        },
      })
    end,
  },
}
