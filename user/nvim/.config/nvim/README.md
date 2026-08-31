# Neovim configuration

This is a personal [LazyVim](https://www.lazyvim.org/) configuration. Its main
custom subsystem connects the shared `project-root-picker` scripts to Neovim,
keeps the working directory aligned with the selected project, and saves or
restores a `persistence.nvim` session when crossing project boundaries.

Project roots are discovered below the directories listed in
`~/.config/project-root-picker/project-roots`. Marker names and path
normalization live in `lua/config/project_paths.lua`; both the picker and the
outside-project buffer cleanup use that module. Symlinked paths, including new
files whose final component does not exist yet, are resolved through their
nearest existing ancestor.

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

## Tests

Run the headless Plenary suite from this directory:

```sh
nvim --headless --clean -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/spec { minimal_init = 'tests/minimal_init.lua' }" \
  -c qa
```

The specs cover buffer cleanup, root/path normalization (including new files
below symlinks), and source/destination session safety.
