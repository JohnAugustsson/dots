return {
  {
    "uZer/pywal16.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      local function fix()
        local set = vim.api.nvim_set_hl

        set(0, "Comment", { italic = true })

        -- critical ones
        set(0, "NonText", { fg = "#C37C85" })

        set(0, "Visual", {
          fg = "#0E0D0F",
          bg = "#9b8889",
          reverse = false,
        })

        set(0, "SnacksPickerDir", {
          fg = "#C37C85",
          bold = true,
        })
      end

      -- apply after colorscheme
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          vim.schedule(fix)
        end,
      })

      vim.cmd.colorscheme("pywal16")

      -- apply again after everything settles
      vim.schedule(fix)
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "pywal16",
    },
  },
}
