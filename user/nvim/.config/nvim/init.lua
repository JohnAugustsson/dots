-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
require("config.project_picker").setup()

local stash = "z"

vim.keymap.set("n", "p", [["+p]], { noremap = true, silent = true })
vim.keymap.set("n", "P", [["+P]], { noremap = true, silent = true })
vim.keymap.set("x", "p", [["_d"+P]], { noremap = true, silent = true })
vim.keymap.set("x", "P", [["_d"+P]], { noremap = true, silent = true })
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
