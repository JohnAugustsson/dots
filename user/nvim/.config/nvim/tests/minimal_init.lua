vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim"))
vim.cmd("runtime plugin/plenary.vim")
vim.opt.swapfile = false
vim.opt.hidden = true
