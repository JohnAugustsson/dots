-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
require("config.project_picker").setup()

local stash = "z"

vim.opt.clipboard = "unnamedplus"

vim.keymap.set({ "n", "x" }, "<M-p>", '"' .. stash .. "p", { noremap = true, silent = true })
vim.keymap.set({ "n", "x" }, "<M-P>", '"' .. stash .. "P", { noremap = true, silent = true })

local swedish_bracket_ns = vim.api.nvim_create_namespace("swedish_bracket_remap")
local swedish_bracket_map = {
  ["å"] = "[",
  ["¨"] = "]",
  ["ö"] = "{",
  ["ä"] = "}",
  ["Å"] = "{",
  ["^"] = "}",
}

vim.on_key(nil, swedish_bracket_ns)
vim.on_key(function(key, typed)
  local replacement = swedish_bracket_map[typed]
  if not replacement then
    return nil
  end

  local mode = vim.api.nvim_get_mode().mode
  if mode:sub(1, 1) == "t" then
    return nil
  end

  vim.schedule(function()
    vim.api.nvim_input(replacement)
  end)
  return ""
end, swedish_bracket_ns)

vim.keymap.set({ "n", "x" }, "d", '"' .. stash .. "d", { noremap = true, silent = true, desc = "Delete To Stash Register" })
vim.keymap.set("n", "D", '"' .. stash .. "D", { noremap = true, silent = true, desc = "Delete Line Tail To Stash Register" })

vim.keymap.set({ "n", "x" }, "c", '"' .. stash .. "c", { noremap = true, silent = true, desc = "Change To Stash Register" })
vim.keymap.set("n", "C", '"' .. stash .. "C", { noremap = true, silent = true, desc = "Change Line Tail To Stash Register" })

vim.keymap.set({ "n", "x" }, "x", [["_x]], { noremap = true, silent = true, desc = "Delete Char To Black Hole" })
vim.keymap.set("n", "X", [["_X]], { noremap = true, silent = true, desc = "Delete Previous Char To Black Hole" })
vim.keymap.set({ "n", "x" }, "s", '"' .. stash .. "s", { noremap = true, silent = true })
vim.keymap.set("n", "S", '"' .. stash .. "S", { noremap = true, silent = true })

vim.opt.statuscolumn = "%{v:lnum}%s %{v:relnum}"
