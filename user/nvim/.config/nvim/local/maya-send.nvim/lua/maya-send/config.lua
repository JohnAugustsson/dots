local M = {}

M.defaults = {
  -- Maya's commandPort, opened from inside Maya with:
  --   cmds.commandPort(name=":7001", sourceType="mel")
  host = "127.0.0.1",
  port = 7001,

  -- Maya reads these from its own process, so they have to live on a
  -- filesystem both Neovim and Maya can see.
  files = {
    code = "/tmp/nvim_maya_temp.py",
    bootstrap = "/tmp/nvim_maya_boot.py",
    output = "/tmp/nvim_maya_output.log",
  },

  keys = {
    -- Normal mode sends the whole buffer, visual mode the selection.
    -- Set to false to skip the default mappings.
    send = "<M-E>",
  },
}

M.options = vim.deepcopy(M.defaults)

function M.set(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

return M
