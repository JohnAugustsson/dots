# maya-send.nvim

Sends Python from a Neovim buffer to a running Maya over its commandPort, the
way an interactive cell would: stdout and stderr show up in Maya's script
editor and in a log file, the final bare expression is echoed through
`sys.displayhook`, and imports and definitions persist in Maya's `__main__`
between sends.

## Setup

Open the port from inside Maya (userSetup.py or the script editor):

```python
from maya import cmds
cmds.commandPort(name=":7001", sourceType="mel")
```

Then, with lazy.nvim:

```lua
{
  dir = vim.fn.stdpath("config") .. "/local/maya-send.nvim",
  opts = {},
}
```

## Options

```lua
require("maya-send").setup({
  host = "127.0.0.1",
  port = 7001,
  files = {
    code = "/tmp/nvim_maya_temp.py",
    bootstrap = "/tmp/nvim_maya_boot.py",
    output = "/tmp/nvim_maya_output.log",
  },
  keys = {
    send = "<M-E>", -- false to skip the default mappings
  },
})
```

Maya opens `files.code` and `files.bootstrap` itself, so they must be readable
from Maya's process.

## Usage

| Mapping / command | Sends |
| --- | --- |
| `<M-E>` (normal) | the whole buffer |
| `<M-E>` (visual) | the selection, dedented |
| `:MayaSend` | the whole buffer |
| `:'<,'>MayaSend` | the given range, dedented |

Output is appended to `files.output`, so `tail -f /tmp/nvim_maya_output.log`
works as a console next to Maya.

`:checkhealth maya-send` reports whether the commandPort answers.
