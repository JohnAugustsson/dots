return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.clangd = opts.servers.clangd or {}
      opts.servers.clangd.keys = {
        {
          "<leader>ch",
          function()
            require("config.unreal_switch").switch()
          end,
          desc = "Switch Header/Source",
        },
      }
    end,
  },
}
