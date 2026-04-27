-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<leader>ch", function()
  require("config.unreal_switch").switch()
end, { desc = "Switch Header/Source" })

vim.keymap.set("n", "<C-f>", function()
  require("config.project_picker").pick_root_entries()
end, { desc = "Project Root Search" })
