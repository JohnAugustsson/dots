-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.clipboard = "unnamedplus"
vim.opt.virtualedit = "onemore"

-- 'autoread' makes the buffer reload automatically as long as the buffer itself has no unsaved changes.
-- :checktime is the command that performs the external-change check, and if 'autoread' is set, Neovim reloads the buffer instead of just warning
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  pattern = "*",
  command = "checktime",
})
