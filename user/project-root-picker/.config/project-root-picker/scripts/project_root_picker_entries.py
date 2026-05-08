#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import signal
import subprocess
import sys
from pathlib import Path

HELPER = Path.home() / '.config/project-root-picker/scripts/project_root_picker.py'
EXCLUDES = ['.git', 'node_modules', '.svelte-kit', 'dist', 'build']
COLORS = {
    'reset': '\033[0m',
    'root': '\033[1;38;2;240;221;222m',
    'dir': '\033[38;2;122;132;163m',
    'file': '\033[38;2;222;195;196m',
}
signal.signal(signal.SIGPIPE, signal.SIG_DFL)

ICONS = {
    'root': '',
    'dir': '',
    'file': '',
}


def columns() -> int:
    for key in ('FZF_COLUMNS', 'COLUMNS'):
        value = os.environ.get(key)
        if value and value.isdigit():
            return int(value)
    try:
        return os.get_terminal_size().columns
    except OSError:
        return 80


def left_truncate(text: str, width: int) -> str:
    if len(text) <= width:
        return text
    if width <= 1:
        return text
    return '…' + text[-(width - 1):]


def display_width() -> int:
    list_cols = max(20, int(columns() * 0.45))
    return max(20, list_cols - 8)


def color_file_path(path: str) -> str:
    parent, sep, name = path.rpartition('/')
    if not sep:
        return f"{COLORS['file']}{path}{COLORS['reset']}"
    return f"{COLORS['dir']}{parent}{sep}{COLORS['reset']}{COLORS['file']}{name}{COLORS['reset']}"




def print_root(label: str, path: Path) -> None:
    print(f"{COLORS['root']}{ICONS['root']}  {label}{COLORS['reset']}\t{path}")


def stream_fd(root: Path, kind: str) -> None:
    width = display_width()
    cmd = ['fd', '--hidden', '--follow', '--type', kind]
    for ex in EXCLUDES:
        cmd.extend(['--exclude', ex])
    cmd.extend(['.', str(root)])

    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    except OSError:
        return

    assert proc.stdout is not None
    for raw in proc.stdout:
        path_s = raw.rstrip('\n')
        if not path_s:
            continue
        try:
            rel = str(Path(path_s).resolve().relative_to(root))
        except ValueError:
            rel = path_s
        if kind == 'directory':
            rel = rel.rstrip('/') + '/'
            shown = left_truncate(rel, width)
            print(f"{COLORS['dir']}{ICONS['dir']}  {shown}{COLORS['reset']}\t{path_s.rstrip('/')}/")
        else:
            shown = left_truncate(rel, width)
            print(f"{COLORS['file']}{ICONS['file']}  {color_file_path(shown)}\t{path_s}")
    proc.wait()


def stream_path_scope(scope: str, start: str) -> int:
    if scope == 'cwd':
        root = Path(start).expanduser().resolve()
        if not root.is_dir():
            root = root.parent
        print_root('./', root)
    elif scope in {'home', 'global'}:
        root = Path.home().resolve()
        print_root('~/', root)
    else:
        return subprocess.call([str(HELPER), '--scope', scope, '--start', start], stderr=subprocess.DEVNULL)

    stream_fd(root, 'directory')
    stream_fd(root, 'file')
    return 0


def grep_scope(scope: str, start: str, query: str) -> int:
    if not query:
        return 0
    return subprocess.call([str(HELPER), '--scope', scope, '--start', start, '--grep', query], stderr=subprocess.DEVNULL)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', nargs='?', default='path', choices=('path', 'grep'))
    parser.add_argument('scope', nargs='?', default='roots')
    parser.add_argument('start', nargs='?', default='.')
    parser.add_argument('query', nargs='?', default='')
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.mode == 'grep':
        return grep_scope(args.scope, args.start, args.query)
    return stream_path_scope(args.scope, args.start)


if __name__ == '__main__':
    raise SystemExit(main())
