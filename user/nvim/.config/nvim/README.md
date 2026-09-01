# Neovim configuration

This is a personal [LazyVim](https://www.lazyvim.org/) configuration. Its main
custom subsystem uses
[`project-root-picker`](https://github.com/JohnAugustsson/project-root-picker)
to search projects, keep the working directory aligned with the selected
project, and save or restore a `persistence.nvim` session when crossing project
boundaries.

Project roots are discovered below the directories listed in
`~/.config/project-root-picker/project-roots`. Discovery, path normalization,
session switching, and outside-project buffer cleanup now live in the external
plugin so Bash, Fish, and Neovim share one implementation.

Session switches are deliberately conservative:

- Any modified buffer, including an unlisted one, and any running terminal
  blocks a switch.
- A destination file already opened by `BufReadPost` is temporarily excluded
  while the source session is saved.
- The destination starts clean even when it has no saved session.
- The switching guard is cleared if saving, changing directory, or loading
  fails.

The project search mappings are `<C-f>` (all configured roots), `<C-g>` (home),
`<C-d>` (current project), `<C-b>` (cwd), and `<leader>fp` (projects only).

The plugin repository contains the Python, shell, installer, and headless
Neovim tests for this subsystem.
