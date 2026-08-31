-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.clipboard = ""
local kitty_scrollback = vim.env.KITTY_SCROLLBACK_NVIM == "true"
if not kitty_scrollback then
  vim.opt.clipboard = "unnamedplus"
end

-- Keep a stalled Wayland clipboard owner from blocking Neovim indefinitely.
local wayland_clipboard_available = not kitty_scrollback
  and vim.env.WAYLAND_DISPLAY ~= nil
  and vim.env.WAYLAND_DISPLAY ~= ""
  and vim.fn.executable("wl-copy") == 1
  and vim.fn.executable("wl-paste") == 1
  and vim.fn.executable("timeout") == 1

if wayland_clipboard_available then
  vim.g.clipboard = {
    name = "wl-clipboard (bounded reads)",
    copy = {
      ["+"] = { "wl-copy", "--type", "text/plain" },
      ["*"] = { "wl-copy", "--primary", "--type", "text/plain" },
    },
    paste = {
      ["+"] = { "timeout", "--kill-after=1s", "5s", "wl-paste", "--no-newline" },
      ["*"] = { "timeout", "--kill-after=1s", "5s", "wl-paste", "--no-newline", "--primary" },
    },
    cache_enabled = 1,
  }
end

vim.opt.virtualedit = "onemore"

-- 'autoread' makes the buffer reload automatically as long as the buffer itself has no unsaved changes.
-- :checktime is the command that performs the external-change check, and if 'autoread' is set, Neovim reloads the buffer instead of just warning
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  pattern = "*",
  command = "checktime",
})
