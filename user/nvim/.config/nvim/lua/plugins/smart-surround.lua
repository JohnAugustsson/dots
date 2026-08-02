return {
  { import = "lazyvim.plugins.extras.coding.mini-surround" },
  {
    "nvim-mini/mini.surround",
    opts = function(_, opts)
      opts.mappings = opts.mappings or {}
      opts.mappings.delete = ""
    end,
    init = function()
      require("config.smart_surround").setup()
    end,
  },
}
