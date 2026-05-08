#!/usr/bin/env python
from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path

RESET = '\033[0m'
HEADER = '\033[1;38;2;240;221;222m'
MATCH_BG = '\033[30;48;2;240;221;222m'
BG_OFF = '\033[49m'
ANSI_RE = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')


def compile_pattern(query: str) -> re.Pattern[str]:
    flags = 0 if any(ch.isupper() for ch in query) else re.IGNORECASE
    try:
        return re.compile(query, flags)
    except re.error:
        return re.compile(re.escape(query), flags)


def load_matches(path: Path, query: str) -> tuple[list[str], list[tuple[int, int, int]]]:
    try:
        lines = path.read_text(errors='replace').splitlines()
    except OSError:
        return [], []

    if not query:
        return lines, []

    pat = compile_pattern(query)
    matches: list[tuple[int, int, int]] = []
    for line_no, line in enumerate(lines, start=1):
        for match in pat.finditer(line):
            start, end = match.span()
            if start == end:
                continue
            matches.append((line_no, start, end))
    return lines, matches


def read_state(state_file: Path, path: Path, query: str) -> int:
    try:
        raw = state_file.read_text().rstrip('\n')
    except OSError:
        return 1
    parts = raw.split('\t')
    if len(parts) >= 3 and parts[0] == str(path) and parts[1] == query:
        try:
            return max(1, int(parts[2]))
        except ValueError:
            return 1
    return 1


def write_state(state_file: Path, path: Path, query: str, idx: int) -> None:
    try:
        state_file.write_text(f'{path}\t{query}\t{idx}\n')
    except OSError:
        pass


def visible_spans_to_ansi_indexes(ansi_line: str) -> tuple[str, list[int]]:
    visible: list[str] = []
    positions: list[int] = []
    i = 0
    while i < len(ansi_line):
        m = ANSI_RE.match(ansi_line, i)
        if m:
            i = m.end()
            continue
        visible.append(ansi_line[i])
        positions.append(i)
        i += 1
    positions.append(len(ansi_line))
    return ''.join(visible), positions


def add_match_background(ansi_line: str, query: str) -> str:
    if not query:
        return ansi_line
    visible, positions = visible_spans_to_ansi_indexes(ansi_line)
    if not visible:
        return ansi_line

    pat = compile_pattern(query)
    inserts: list[tuple[int, str]] = []
    for match in pat.finditer(visible):
        if match.start() == match.end():
            continue
        inserts.append((positions[match.start()], MATCH_BG))
        inserts.append((positions[match.end()], BG_OFF))
    if not inserts:
        return ansi_line

    out = ansi_line
    for pos, text in sorted(inserts, key=lambda item: item[0], reverse=True):
        out = out[:pos] + text + out[pos:]
    return out


def bat_lines(path: Path, start: int, end: int) -> list[str]:
    cmd = [
        'bat',
        '--style=plain',
        '--color=always',
        f'--line-range={start}:{end}',
        str(path),
    ]
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, check=False)
    except OSError:
        try:
            raw = path.read_text(errors='replace').splitlines()
        except OSError:
            return []
        return raw[start - 1:end]
    return proc.stdout.splitlines()


def preview(args: argparse.Namespace) -> int:
    path = Path(args.path)
    query = args.query or ''
    lines, matches = load_matches(path, query)
    if not lines:
        return 0

    if not matches:
        for line in bat_lines(path, 1, min(len(lines), 200)):
            print(line)
        return 0

    current = read_state(Path(args.state), path, query)
    if current < 1 or current > len(matches):
        current = 1
    write_state(Path(args.state), path, query, current)

    active_line, _, _ = matches[current - 1]
    start = max(1, active_line - args.context)
    end = min(len(lines), active_line + args.context)

    print(f'{HEADER}match {current}/{len(matches)}  line {active_line}  {path}{RESET}')
    print()
    for line in bat_lines(path, start, end):
        print(add_match_background(line, query))
    return 0


def nav(args: argparse.Namespace) -> int:
    path = Path(args.path)
    query = args.query or ''
    _, matches = load_matches(path, query)
    if not matches:
        return 0

    state = Path(args.state)
    current = read_state(state, path, query)
    current += args.delta
    if current < 1:
        current = len(matches)
    elif current > len(matches):
        current = 1
    write_state(state, path, query, current)
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest='cmd', required=True)

    p_preview = sub.add_parser('preview')
    p_preview.add_argument('--state', required=True)
    p_preview.add_argument('--query', required=True)
    p_preview.add_argument('--path', required=True)
    p_preview.add_argument('--context', type=int, default=10)
    p_preview.set_defaults(func=preview)

    p_nav = sub.add_parser('nav')
    p_nav.add_argument('--state', required=True)
    p_nav.add_argument('--query', required=True)
    p_nav.add_argument('--path', required=True)
    p_nav.add_argument('--delta', type=int, required=True)
    p_nav.set_defaults(func=nav)

    return parser.parse_args()


def main() -> int:
    args = parse_args()
    return args.func(args)


if __name__ == '__main__':
    raise SystemExit(main())
