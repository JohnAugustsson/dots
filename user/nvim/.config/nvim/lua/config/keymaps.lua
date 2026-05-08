-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<leader>ch", function()
  require("config.unreal_switch").switch()
end, { desc = "Switch Header/Source" })

vim.keymap.set("n", "<C-f>", function()
  require("config.project_picker").pick_root_entries()
end, { desc = "Project Root Search" })

vim.keymap.set("n", "<C-g>", function()
  require("config.project_picker").pick_home_entries()
end, { desc = "Home Search" })

vim.keymap.set("n", "<C-d>", function()
  require("config.project_picker").pick_project_entries()
end, { desc = "Current Project Search" })

vim.keymap.set("n", "<C-p>", function()
  require("config.project_picker").pick_cwd_entries()
end, { desc = "Cwd Search" })
