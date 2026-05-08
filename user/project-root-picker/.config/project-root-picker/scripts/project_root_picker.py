#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import os
import signal
import subprocess
import sys
from pathlib import Path

signal.signal(signal.SIGPIPE, signal.SIG_DFL)

ROOTS_FILE = Path.home() / '.config/project-root-picker/project-roots'
EXCLUDES = ['.git', 'node_modules', '.svelte-kit', 'dist', 'build']
COLORS = {
    'reset': '\033[0m',
    'project': '\033[1;38;2;214;144;152m',
    'root': '\033[1;38;2;240;221;222m',
    'dir': '\033[38;2;122;132;163m',
    'file': '\033[38;2;222;195;196m',
}
ICONS = {
    'root': '',
    'dir': '',
    'file': '',
}
MARKERS = ('.project-root', '.gitignore')


def terminal_columns() -> int:
    for key in ('FZF_COLUMNS', 'COLUMNS'):
        value = os.environ.get(key)
        if value and value.isdigit():
            return int(value)
    try:
        return int(subprocess.check_output(['tput', 'cols'], stderr=subprocess.DEVNULL, text=True).strip())
    except Exception:
        return 80


def left_truncate(text: str, max_width: int) -> str:
    if max_width <= 1:
        return text
    if len(text) <= max_width:
        return text
    return '…' + text[-(max_width - 1):]


def normalize(path: Path) -> Path:
    try:
        return path.expanduser().resolve()
    except OSError:
        return path.expanduser().absolute()


def load_roots(sort_by_depth: bool = True) -> list[Path]:
    if not ROOTS_FILE.exists():
        return []
    roots: list[Path] = []
    with ROOTS_FILE.open() as f:
        for raw in f:
            p = raw.strip()
            if not p:
                continue
            path = normalize(Path(p))
            if path.is_dir():
                roots.append(path)
    if sort_by_depth:
        roots.sort(key=lambda p: len(str(p)), reverse=True)
    return roots


def fd_entries(root: Path) -> list[Path]:
    cmd = ['fd', '--hidden', '--follow']
    for ex in EXCLUDES:
        cmd.extend(['--exclude', ex])
    cmd.extend(['.', str(root)])
    out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True)
    return [root, *[normalize(Path(line)) for line in out.splitlines() if line.strip()]]


def path_is_inside(path: Path, root: Path) -> bool:
    path_s = str(path)
    root_s = str(root)
    return path_s == root_s or path_s.startswith(root_s.rstrip('/') + '/')


def is_inside_saved_root(path: Path, roots: list[Path]) -> bool:
    return any(path_is_inside(path, root) for root in roots)


def find_project_root(start: Path, saved_roots: list[Path] | None = None) -> Path | None:
    path = normalize(start)
    probe = path if path.is_dir() else path.parent

    while True:
        for marker in MARKERS:
            if (probe / marker).exists():
                if saved_roots is None or is_inside_saved_root(probe, saved_roots):
                    return probe
        parent = probe.parent
        if parent == probe:
            return None
        probe = parent


def detect_project(label_dir: Path, root: Path, root_name: str) -> tuple[str, Path | None]:
    probe = label_dir
    while True:
        for marker in MARKERS:
            if (probe / marker).exists():
                return probe.name, probe
        if probe == root:
            break
        parent = probe.parent
        if parent == probe:
            break
        probe = parent
    return root_name, None


def build_rows(roots: list[Path]) -> list[tuple[str, str, str, str]]:
    seen: set[str] = set()
    rows: list[tuple[str, str, str, str]] = []
    for root in roots:
        root = normalize(root)
        root_str = str(root)
        root_name = root.name or root_str
        root_re = re.compile(r'^' + re.escape(root_str) + r'/?')
        for entry in fd_entries(root):
            entry_str = str(entry)
            if entry_str in seen:
                continue
            seen.add(entry_str)

            if entry == root:
                rel_path = './'
                kind = 'root'
                label_dir = root
            else:
                rel_path = root_re.sub('', entry_str)
                if entry.is_dir():
                    rel_path = rel_path + '/'
                    kind = 'dir'
                    label_dir = entry
                else:
                    kind = 'file'
                    label_dir = entry.parent

            project_name, project_dir = detect_project(label_dir, root, root_name)
            if project_dir is not None and entry == project_dir:
                rel_path = './'
                kind = 'root'

            rows.append((project_name, rel_path, entry_str, kind))
    return rows


def build_project_rows(roots: list[Path]) -> list[tuple[str, str, str, str]]:
    rows = build_rows(roots)
    projects: list[tuple[str, str, str, str]] = []
    seen_paths: set[str] = set()
    for project_name, rel_path, path, kind in rows:
        if kind != 'root':
            continue
        if path in seen_paths:
            continue
        seen_paths.add(path)
        projects.append((project_name, './', path, 'root'))
    return projects


def select_roots(args: argparse.Namespace) -> list[Path]:
    saved_roots = load_roots()
    start = normalize(Path(args.start))

    if args.scope == 'roots':
        return saved_roots
    if args.scope == 'cwd':
        return [start] if start.is_dir() else [start.parent]
    if args.scope == 'project':
        project = find_project_root(start, saved_roots)
        return [project] if project is not None else []
    if args.scope == 'home':
        return [Path.home()]
    if args.scope == 'global':
        return [Path('/')]

    return saved_roots


PROJECT_STREAM_WIDTH = 18


def display_width_for_project(project_width: int) -> int:
    columns = terminal_columns()
    list_columns = max(20, int(columns * 0.95))
    return max(20, list_columns - project_width - 8)


def format_row(project: str, rel_path: str, path: str, kind: str, ansi: bool = True, project_width: int | None = None) -> str:
    width = project_width if project_width is not None else len(project)
    display_path = left_truncate(rel_path, display_width_for_project(width))
    if not ansi:
        return f"{project}\t{rel_path}\t{path}\t{kind}"

    color = COLORS[kind]
    icon = ICONS[kind]
    project_display = left_truncate(project, width)
    if kind == 'file':
        parent, sep, name = display_path.rpartition('/')
        display_colored = (
            f"{COLORS['dir']}{parent}{sep}{COLORS['reset']}"
            f"{COLORS['file']}{name}{COLORS['reset']}"
        ) if sep else f"{COLORS['file']}{display_path}{COLORS['reset']}"
    else:
        display_colored = f"{color}{display_path}{COLORS['reset']}"

    return (
        f"{COLORS['project']}{project_display:<{width}}{COLORS['reset']}  "
        f"{color}{icon}{COLORS['reset']}  "
        f"{display_colored}\t{path}"
    )


def fd_cmd(root: Path) -> list[str]:
    cmd = ['fd', '--hidden', '--follow']
    for ex in EXCLUDES:
        cmd.extend(['--exclude', ex])
    cmd.extend(['.', str(root)])
    return cmd


def emit_stream_row(project: str, rel_path: str, path: str, kind: str, seen: set[str]) -> None:
    if path in seen:
        return
    seen.add(path)
    print(format_row(project, rel_path, path, kind, ansi=True, project_width=PROJECT_STREAM_WIDTH), flush=True)


def stream_rows(roots: list[Path]) -> int:
    seen: set[str] = set()
    for root in roots:
        root = normalize(root)
        root_str = str(root)
        root_name = root.name or root_str
        root_re = re.compile(r'^' + re.escape(root_str) + r'/?')
        emit_stream_row(root_name, './', root_str, 'root', seen)

        try:
            proc = subprocess.Popen(fd_cmd(root), stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        except OSError:
            continue

        assert proc.stdout is not None
        for raw in proc.stdout:
            raw = raw.strip()
            if not raw:
                continue
            entry = normalize(Path(raw))
            entry_str = str(entry)
            if entry_str in seen:
                continue

            rel_path = root_re.sub('', entry_str)
            if entry.is_dir():
                rel_path += '/'
                kind = 'dir'
                label_dir = entry
            else:
                kind = 'file'
                label_dir = entry.parent

            project_name, project_dir = detect_project(label_dir, root, root_name)
            if project_dir is not None and entry == project_dir:
                rel_path = './'
                kind = 'root'

            emit_stream_row(project_name, rel_path, entry_str, kind, seen)

        proc.wait()
    return 0


def rg_count_cmd(roots: list[Path], query: str) -> list[str]:
    cmd = [
        'rg',
        '--count-matches',
        '--color=never',
        '--smart-case',
        '--hidden',
        '--follow',
    ]
    for ex in EXCLUDES:
        cmd.extend(['--glob', f'!{ex}/**', '--glob', f'!**/{ex}/**'])
    cmd.append(query)
    cmd.extend(str(root) for root in roots)
    return cmd


def stream_grep_rows(roots: list[Path], query: str) -> int:
    if not query.strip():
        return 0

    try:
        proc = subprocess.Popen(rg_count_cmd(roots, query), stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    except OSError:
        return 1

    assert proc.stdout is not None
    for raw in proc.stdout:
        raw = raw.rstrip('\n')
        if not raw:
            continue
        path_s, sep, count_s = raw.rpartition(':')
        if not sep or not count_s.isdigit():
            continue
        path = normalize(Path(path_s))
        count = int(count_s)
        root = next((root for root in roots if path_is_inside(path, root)), path.parent)
        try:
            rel = str(path.relative_to(root))
        except ValueError:
            rel = str(path)
        project_name, _ = detect_project(path.parent, root, root.name or str(root))
        line = format_row(project_name, rel, str(path), 'file', ansi=True, project_width=PROJECT_STREAM_WIDTH)
        print(f"{count}\t{line}", flush=True)

    proc.wait()
    return 0


def build_grep_rows(roots: list[Path], query: str) -> list[tuple[str, str, str, str]]:
    if not query.strip():
        return []

    cmd = [
        'rg',
        '--column',
        '--line-number',
        '--no-heading',
        '--color=never',
        '--smart-case',
        '--hidden',
        '--follow',
    ]
    for ex in EXCLUDES:
        cmd.extend(['--glob', f'!{ex}/**', '--glob', f'!**/{ex}/**'])
    cmd.append(query)
    cmd.extend(str(root) for root in roots)

    try:
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True)
    except subprocess.CalledProcessError as exc:
        out = exc.output or ''

    by_path: dict[str, dict[str, object]] = {}
    order: list[str] = []
    for raw in out.splitlines():
        parts = raw.split(':', 3)
        if len(parts) < 4:
            continue
        path_s, line, col, text = parts
        path = normalize(Path(path_s))
        path_key = str(path)
        root = next((root for root in roots if path_is_inside(path, root)), path.parent)
        try:
            rel = str(path.relative_to(root))
        except ValueError:
            rel = str(path)
        project_name, _ = detect_project(path.parent, root, root.name or str(root))

        if path_key not in by_path:
            by_path[path_key] = {
                'project': project_name,
                'rel': rel,
                'count': 0,
                'first_line': line,
                'first_col': col,
                'snippet': text.strip(),
            }
            order.append(path_key)
        by_path[path_key]['count'] = int(by_path[path_key]['count']) + 1

    rows: list[tuple[str, str, str, str]] = []
    for path_key in order:
        item = by_path[path_key]
        count = int(item['count'])
        rows.append((str(item['project']), str(item['rel']), path_key, 'file'))
    return rows


def format_rows(rows: list[tuple[str, str, str, str]], ansi: bool = True) -> str:
    width = max((len(project) for project, *_ in rows), default=0)
    return '\n'.join(format_row(project, rel_path, path, kind, ansi=ansi, project_width=width) for project, rel_path, path, kind in rows)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument('--projects-only', action='store_true')
    parser.add_argument('--plain', action='store_true')
    parser.add_argument('--scope', choices=('roots', 'cwd', 'project', 'home', 'global'), default='roots')
    parser.add_argument('--start', default='.')
    parser.add_argument('--grep')
    parser.add_argument('--grep-stream', action='store_true')
    parser.add_argument('--stream', action='store_true')
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.stream:
        if args.scope != 'roots' or args.plain or args.projects_only or args.grep is not None or args.grep_stream:
            return 2
        roots = [root for root in load_roots(sort_by_depth=False) if root.is_dir()]
        if not roots:
            return 1
        return stream_rows(roots)

    roots = select_roots(args)
    roots = [root for root in roots if root.is_dir()]
    if not roots:
        return 1

    if args.grep_stream:
        if args.plain or args.projects_only or args.grep is None:
            return 2
        return stream_grep_rows(roots, args.grep)

    rows = build_grep_rows(roots, args.grep) if args.grep is not None else build_project_rows(roots) if args.projects_only else build_rows(roots)
    sys.stdout.write(format_rows(rows, ansi=not args.plain))
    if rows:
        sys.stdout.write('\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
