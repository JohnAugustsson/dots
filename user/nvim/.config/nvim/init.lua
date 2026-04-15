-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

local stash = "z"

vim.keymap.set("n", "p", [["+p]], { noremap = true, silent = true })
vim.keymap.set("n", "P", [["+P]], { noremap = true, silent = true })
vim.keymap.set("x", "p", [["_d"+P]], { noremap = true, silent = true })
vim.keymap.set("x", "P", [["_d"+P]], { noremap = true, silent = true })
vim.keymap.set({ "n", "x" }, "å", '"' .. stash .. "p", { noremap = true, silent = true })
vim.keymap.set({ "n", "x" }, "Å", '"' .. stash .. "P", { noremap = true, silent = true })

vim.keymap.set({ "n", "x" }, "y", [["+y]], { noremap = true, silent = true })
vim.keymap.set("n", "Y", [["+Y]], { noremap = true, silent = true })

vim.keymap.set({ "n", "x" }, "d", '"' .. stash .. "d", { noremap = true, silent = true })
vim.keymap.set("n", "D", '"' .. stash .. "D", { noremap = true, silent = true })

vim.keymap.set({ "n", "x" }, "c", '"' .. stash .. "c", { noremap = true, silent = true })
vim.keymap.set("n", "C", '"' .. stash .. "C", { noremap = true, silent = true })

vim.keymap.set({ "n", "x" }, "x", '"' .. stash .. "x", { noremap = true, silent = true })
vim.keymap.set("n", "X", '"' .. stash .. "X", { noremap = true, silent = true })
vim.keymap.set({ "n", "x" }, "s", '"' .. stash .. "s", { noremap = true, silent = true })
vim.keymap.set("n", "S", '"' .. stash .. "S", { noremap = true, silent = true })

vim.opt.statuscolumn = "%{v:lnum}%s %{v:relnum}"

vim.keymap.set("n", "<leader>fp", "<cmd>Telescope projects<cr>", { desc = "Projects" })
