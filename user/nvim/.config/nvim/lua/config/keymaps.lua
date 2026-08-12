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

vim.keymap.set("n", "<C-S-d>", function()
  require("config.project_picker").pick_project_entries()
end, { desc = "Current Project Search" })

vim.keymap.set("n", "<C-b>", function()
  require("config.project_picker").pick_cwd_entries()
end, { desc = "Cwd Search" })

vim.keymap.set("n", "<leader>gl", function()
  vim.cmd("new")
  vim.cmd([[read !git log --decorate --date=short --pretty=fuller]])
  vim.cmd("1delete")

  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.bo.modifiable = false
  vim.bo.filetype = "git"
end, { desc = "Git commit log" })

vim.keymap.set("c", "/", function()
  if vim.fn.getcmdtype() == ":" then
    local before = vim.fn.getcmdline():sub(1, vim.fn.getcmdpos() - 1)

    if before:sub(-2) == "%v" then
      return "<BS><BS>s/\\%V"
    end
  end

  return "/"
end, { expr = true })
