-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<leader>ch", function()
  require("config.unreal_switch").switch()
end, { desc = "Switch Header/Source" })

vim.keymap.set("n", "<leader>fp", function()
  require("project_root_picker").pick_projects()
end, { desc = "Projects" })

vim.keymap.set("n", "<C-f>", function()
  require("project_root_picker").pick({ scope = "roots" })
end, { desc = "Project Root Search" })

vim.keymap.set("n", "<C-g>", function()
  require("project_root_picker").pick({ scope = "home" })
end, { desc = "Home Search" })

vim.keymap.set("n", "<C-d>", function()
  require("project_root_picker").pick({ scope = "project" })
end, { desc = "Current Project Search" })

vim.keymap.set("n", "<C-b>", function()
  require("project_root_picker").pick({ scope = "cwd" })
end, { desc = "Cwd Search" })
