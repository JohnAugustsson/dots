-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.keymap.set("x", "P", [["_dP]], { noremap = true, silent = true })
vim.keymap.set("x", "p", [["_dP]], { noremap = true, silent = true })

vim.keymap.set({ "n", "x" }, "y", [["+y]], { noremap = true, silent = true })
vim.keymap.set("n", "Y", [["+Y]], { noremap = true, silent = true })

vim.keymap.set({ "n", "x" }, "d", [["_d]], { noremap = true, silent = true })
vim.keymap.set("n", "D", [["_D]], { noremap = true, silent = true })

vim.keymap.set({ "n", "x" }, "c", [["+c]], { noremap = true, silent = true })
vim.keymap.set("n", "C", [["+C]], { noremap = true, silent = true })

vim.keymap.set({ "n", "x" }, "x", [["_x]], { noremap = true, silent = true })
vim.keymap.set("n", "X", [["_X]], { noremap = true, silent = true })
vim.keymap.set({ "n", "x" }, "s", [["_s]], { noremap = true, silent = true })
vim.keymap.set("n", "S", [["_S]], { noremap = true, silent = true })
