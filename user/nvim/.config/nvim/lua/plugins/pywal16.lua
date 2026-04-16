return {
  {
    "uZer/pywal16.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      local function fix()
        local set = vim.api.nvim_set_hl

        -- palette
        local bg = "#0E0D0F"
        local bg_alt = "#161417"
        local bg_sel = "#3A3035"
        local fg = "#DEC3C4"
        local fg_muted = "#8F7B7E"
        local fg_strong = "#F0DDDE"

        local rose = "#9B5F6C"
        local rose_bright = "#B56F7F"

        local slate = "#686E88"
        local slate_bright = "#7A84A3"

        local mauve = "#A27689"
        local mauve_bright = "#BB87A0"

        local pink = "#C37C85"
        local pink_bright = "#D69098"

        local taupe = "#AE8883"
        local taupe_bright = "#C39A93"

        local lavender = "#AD8C9F"
        local lavender_bright = "#C2A0B4"

        -- base editor
        set(0, "Normal", { fg = fg, bg = bg })
        set(0, "NormalNC", { fg = fg, bg = bg })
        set(0, "NormalFloat", { fg = fg, bg = bg_alt })
        set(0, "FloatBorder", { fg = fg_muted, bg = bg_alt })
        set(0, "FloatTitle", { fg = fg_strong, bg = bg_alt, bold = true })

        set(0, "ColorColumn", { bg = bg_alt })
        set(0, "CursorLine", { bg = bg_alt })
        set(0, "CursorLineNr", { fg = fg_strong, bg = bg_alt, bold = true })
        set(0, "LineNr", { fg = fg_muted })
        set(0, "SignColumn", { bg = bg })
        set(0, "EndOfBuffer", { fg = bg })

        -- text / syntax
        set(0, "Comment", { fg = fg_muted, italic = true })
        set(0, "NonText", { fg = fg_muted })
        set(0, "Whitespace", { fg = fg_muted })

        set(0, "Constant", { fg = taupe_bright })
        set(0, "String", { fg = taupe_bright })
        set(0, "Character", { fg = taupe_bright })
        set(0, "Number", { fg = pink_bright })
        set(0, "Boolean", { fg = pink_bright })

        set(0, "Identifier", { fg = fg })
        set(0, "Function", { fg = lavender_bright, bold = true })

        set(0, "Statement", { fg = rose_bright })
        set(0, "Conditional", { fg = rose_bright, bold = true })
        set(0, "Repeat", { fg = rose_bright })
        set(0, "Keyword", { fg = rose_bright, italic = true })
        set(0, "Operator", { fg = mauve_bright })

        set(0, "PreProc", { fg = mauve_bright })
        set(0, "Type", { fg = slate_bright, bold = true })
        set(0, "Special", { fg = pink_bright })

        -- selection / search
        set(0, "Visual", { fg = "NONE", bg = bg_sel })
        set(0, "Search", { fg = fg_strong, bg = mauve })
        set(0, "IncSearch", { fg = bg, bg = pink_bright, bold = true })
        set(0, "CurSearch", { fg = bg, bg = lavender_bright, bold = true })
        set(0, "MatchParen", { fg = fg_strong, bg = slate, bold = true })
        -- popup menu
        set(0, "Pmenu", { fg = fg, bg = bg_alt })
        set(0, "PmenuSel", { fg = fg_strong, bg = bg_sel, bold = true })
        set(0, "PmenuSbar", { bg = bg_alt })
        set(0, "PmenuThumb", { bg = fg_muted })

        -- splits / borders
        set(0, "WinSeparator", { fg = fg_muted, bg = bg })

        -- messages / titles
        set(0, "Title", { fg = fg_strong, bold = true })
        set(0, "Directory", { fg = pink_bright, bold = true })

        -- diagnostics
        set(0, "DiagnosticError", { fg = rose_bright })
        set(0, "DiagnosticWarn", { fg = taupe_bright })
        set(0, "DiagnosticInfo", { fg = slate_bright })
        set(0, "DiagnosticHint", { fg = lavender_bright })

        set(0, "DiagnosticVirtualTextError", { fg = rose_bright, bg = bg_alt })
        set(0, "DiagnosticVirtualTextWarn", { fg = taupe_bright, bg = bg_alt })
        set(0, "DiagnosticVirtualTextInfo", { fg = slate_bright, bg = bg_alt })
        set(0, "DiagnosticVirtualTextHint", { fg = lavender_bright, bg = bg_alt })

        set(0, "DiagnosticUnderlineError", { undercurl = true, sp = rose_bright })
        set(0, "DiagnosticUnderlineWarn", { undercurl = true, sp = taupe_bright })
        set(0, "DiagnosticUnderlineInfo", { undercurl = true, sp = slate_bright })
        set(0, "DiagnosticUnderlineHint", { undercurl = true, sp = lavender_bright })

        -- telescope
        set(0, "TelescopeNormal", { fg = fg, bg = bg_alt })
        set(0, "TelescopeBorder", { fg = fg_muted, bg = bg_alt })
        set(0, "TelescopeTitle", { fg = fg_strong, bg = bg_alt, bold = true })
        set(0, "TelescopePromptNormal", { fg = fg, bg = bg_alt })
        set(0, "TelescopePromptBorder", { fg = fg_muted, bg = bg_alt })
        set(0, "TelescopePromptTitle", { fg = bg, bg = pink_bright, bold = true })
        set(0, "TelescopePreviewTitle", { fg = bg, bg = lavender_bright, bold = true })
        set(0, "TelescopeResultsTitle", { fg = bg, bg = slate_bright, bold = true })
        set(0, "TelescopeSelection", { fg = fg_strong, bg = bg_sel, bold = true })
        set(0, "TelescopeSelectionCaret", { fg = pink_bright, bg = bg_sel, bold = true })
        set(0, "TelescopeMatching", { fg = fg_strong, bold = true })

        -- snacks explorer / picker
        set(0, "SnacksPickerDir", { fg = pink_bright, bold = true })
        set(0, "SnacksPickerFile", { fg = fg })
        set(0, "SnacksPickerMatch", { fg = fg_strong, bold = true })
        set(0, "SnacksIndent", { fg = fg_muted })
        set(0, "SnacksIndentScope", { fg = mauve_bright })

        -- common tree plugins, harmless if unused
        set(0, "NeoTreeDirectoryName", { fg = pink_bright, bold = true })
        set(0, "NeoTreeDirectoryIcon", { fg = pink_bright, bold = true })
        set(0, "NeoTreeRootName", { fg = fg_strong, bold = true })
      end

      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          vim.schedule(fix)
        end,
      })

      vim.cmd.colorscheme("pywal16")
      vim.schedule(fix)
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "pywal16",
    },
  },
}
