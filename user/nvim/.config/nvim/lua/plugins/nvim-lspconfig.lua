-- gbk python lsp
return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      pyright = {
        settings = {
          python = {
            analysis = {
              logLevel = "Trace",
              diagnosticSeverityOverrides = {
                reportMissingModuleSource = "none",
              },
              extraPaths = {
                "/mnt/home/john.augustsson/Local/misc-dev/maya-stubs",
                "/mnt/home/john.augustsson/Local/uTools/Maya/scripts",
                "/mnt/home/john.augustsson/Local/pipeline/libraries/toto-maya",
                "/mnt/home/john.augustsson/Local/pipeline/libraries/toto-core",
                "/mnt/home/john.augustsson/.local/share/pipeline-packages/maya-2026/lib/python3.11/site-packages",
              },
            },
          },
        },
      },
    },
  },
}
