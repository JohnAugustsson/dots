vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_clients({ id = args.data.client_id })[1]
    if not client or client.name ~= "clangd" then
      return
    end

    vim.keymap.set("n", "<leader>ch", function()
      require("config.unreal_switch").switch()
    end, { buffer = args.buf, desc = "Switch Header/Source" })
  end,
})
