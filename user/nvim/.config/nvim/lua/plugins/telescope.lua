local function live_grep_current_project()
  local builtin = require("telescope.builtin")
  local project = require("config.project_picker")
  local cwd = project._current_project_root() or vim.fn.getcwd()
  builtin.live_grep({ cwd = cwd, prompt_title = "Live Grep Current Project" })
end

local function live_grep_all_projects()
  local builtin = require("telescope.builtin")
  local project = require("config.project_picker")
  local roots = project._load_saved_roots()
  if #roots == 0 then
    vim.notify("No project roots configured. Use: project-root", vim.log.levels.WARN)
    return
  end
  builtin.live_grep({ search_dirs = roots, prompt_title = "Live Grep All Projects" })
end

local function live_grep_home()
  require("telescope.builtin").live_grep({ cwd = vim.fn.expand("~"), prompt_title = "Live Grep ~" })
end

local function live_grep_global()
  require("telescope.builtin").live_grep({ cwd = "/", prompt_title = "Live Grep /" })
end

local function yank_undo_to_plus(field)
  return function(prompt_bufnr)
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local entry = action_state.get_selected_entry()
    if entry == nil then
      return
    end

    local value = entry.value[field]
    vim.fn.setreg("+", value, (#value > 1) and "V" or "v")
    actions.close(prompt_bufnr)
    return value
  end
end

local function yanky_put_from_plus(type, is_visual)
  return function()
    require("yanky").put(type, is_visual, function(state, put)
      state.register = "+"
      put(state)
    end)
  end
end

return {
  {
    "gbprod/yanky.nvim",
    opts = function(_, opts)
      opts.ring = opts.ring or {}
      opts.ring.ignore_registers = { "_", "z" }
      opts.ring.sync_with_numbered_registers = false
    end,
    keys = {
      {
        "y",
        function()
          return require("yanky").yank({ register = "+" })
        end,
        mode = { "n", "x" },
        expr = true,
        desc = "Yank Text To System Clipboard",
      },
      { "Y", [=["+yy]=], desc = "Yank Line To System Clipboard" },
      { "p", yanky_put_from_plus("p", false), mode = "n", desc = "Put Text From System Clipboard" },
      { "P", yanky_put_from_plus("P", false), mode = "n", desc = "Put Text Before From System Clipboard" },
      { "p", yanky_put_from_plus("p", true), mode = "x", desc = "Replace With System Clipboard" },
      { "P", yanky_put_from_plus("P", true), mode = "x", desc = "Replace Before With System Clipboard" },
      { "<C-p>", "<Plug>(YankyPreviousEntry)", desc = "Cycle Previous Yank History Entry" },
      { "<C-n>", "<Plug>(YankyNextEntry)", desc = "Cycle Next Yank History Entry" },
    },
  },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "debugloop/telescope-undo.nvim",
    },
    keys = {
      {
        "<leader>r",
        function()
          require("telescope").extensions.undo.undo()
        end,
        desc = "Undo History",
      },
      { "<leader>fg", live_grep_current_project, desc = "Grep Current Project" },
      { "<leader>fG", live_grep_all_projects, desc = "Grep All Projects" },
      { "<leader>fh", live_grep_home, desc = "Grep Home" },
      { "<leader>fH", live_grep_global, desc = "Grep Global" },
    },
    opts = function(_, opts)
      opts.extensions = vim.tbl_deep_extend("force", opts.extensions or {}, {
        project = {
          hidden_files = true,
        },
        undo = {
          prompt_title = "Undo History",
          results_title = "j/k move · <CR>/y yank+ · <S-CR>/Y yank- · <C-r>/u restore · q close",
          preview_title = "Added/Removed diff",
          mappings = {
            i = {
              ["<CR>"] = yank_undo_to_plus("additions"),
              ["<S-CR>"] = yank_undo_to_plus("deletions"),
              ["<C-y>"] = yank_undo_to_plus("deletions"),
            },
            n = {
              ["y"] = yank_undo_to_plus("additions"),
              ["Y"] = yank_undo_to_plus("deletions"),
            },
          },
        },
      })
      opts.pickers = vim.tbl_deep_extend("force", opts.pickers or {}, {
        find_files = {
          hidden = true,
        },
      })
    end,
    config = function(_, opts)
      require("telescope").setup(opts)
      require("telescope").load_extension("undo")
    end,
  },
}
