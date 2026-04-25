#!/usr/bin/env python
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOTS_FILE = Path.home() / '.config/fish/project-roots'
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


def load_roots() -> list[Path]:
    if not ROOTS_FILE.exists():
        return []
    roots: list[Path] = []
    with ROOTS_FILE.open() as f:
        for raw in f:
            p = raw.strip()
            if not p:
                continue
            path = Path(p)
            if path.is_dir():
                roots.append(path)
    roots.sort(key=lambda p: len(str(p)), reverse=True)
    return roots


def fd_entries(root: Path) -> list[Path]:
    cmd = ['fd', '--hidden', '--follow']
    for ex in EXCLUDES:
        cmd.extend(['--exclude', ex])
    cmd.extend(['.', str(root)])
    out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True)
    return [root, *[Path(line) for line in out.splitlines() if line.strip()]]


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
        root_str = str(root)
        root_name = root.name
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


def format_rows(rows: list[tuple[str, str, str, str]], ansi: bool = True) -> str:
    width = max((len(project) for project, *_ in rows), default=0)
    lines: list[str] = []
    for project, rel_path, path, kind in rows:
        if ansi:
            color = COLORS[kind]
            icon = ICONS[kind]
            line = (
                f"{COLORS['project']}{project:<{width}}{COLORS['reset']}  "
                f"{color}{icon}{COLORS['reset']}  "
                f"{color}{rel_path}{COLORS['reset']}\t{path}"
            )
        else:
            line = f"{project}\t{rel_path}\t{path}\t{kind}"
        lines.append(line)
    return '\n'.join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument('--projects-only', action='store_true')
    parser.add_argument('--plain', action='store_true')
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    roots = load_roots()
    if not roots:
        return 1
    rows = build_project_rows(roots) if args.projects_only else build_rows(roots)
    sys.stdout.write(format_rows(rows, ansi=not args.plain))
    if rows:
        sys.stdout.write('\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
