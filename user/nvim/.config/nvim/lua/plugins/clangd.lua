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

      -- Let clangd interrogate nix toolchains for their system headers.
      --
      -- clangd refuses to execute a compiler it does not recognise unless the
      -- driver matches --query-driver, and a nix build always compiles through a
      -- /nix/store gcc wrapper. Without this nothing resolves at all -- not just
      -- the Maya devkit but <cstddef>, and every symbol after it.
      --
      -- Appended to LazyVim's clangd extra rather than replacing its cmd, so
      -- --background-index, --clang-tidy and the rest survive.
      local query_driver = "--query-driver="
        .. table.concat({
          "/nix/store/*/bin/*g++",
          "/nix/store/*/bin/*gcc",
          "/usr/bin/g++",
          "/usr/bin/gcc",
        }, ",")

      opts.servers.clangd.cmd = opts.servers.clangd.cmd or { "clangd" }
      local already_set = false
      for _, arg in ipairs(opts.servers.clangd.cmd) do
        if type(arg) == "string" and arg:match("^%-%-query%-driver=") then
          already_set = true
          break
        end
      end
      if not already_set then
        table.insert(opts.servers.clangd.cmd, query_driver)
      end
    end,
  },
}
