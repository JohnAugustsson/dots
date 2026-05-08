#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

MATCH_HELPER = Path.home() / '.config/project-root-picker/scripts/project_root_picker_match.py'


def extract_path(row: str) -> str:
    parts = row.split('\t')
    return parts[1] if len(parts) >= 2 else row


def run(cmd: list[str]) -> int:
    try:
        proc = subprocess.run(cmd, check=False)
        return proc.returncode
    except OSError:
        return 127


def preview_dir(path: str) -> int:
    code = run(['eza', '-la', '--group-directories-first', '--icons=always', path])
    if code == 127:
        return run(['ls', '-la', path])
    return code


def preview_file(path: str) -> int:
    return run(['bat', '--style=plain', '--color=always', path])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument('mode')
    parser.add_argument('query')
    parser.add_argument('state_file')
    parser.add_argument('row')
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    mode = args.mode
    if mode == 'auto':
        mode = 'grep' if os.environ.get('FZF_PROMPT') == 'rg> ' else 'path'

    path = extract_path(args.row)
    if not path:
        return 0

    p = Path(path)
    if mode == 'grep':
        if p.is_file():
            return run([str(MATCH_HELPER), 'preview', '--state', args.state_file, '--query', args.query, '--path', path])
        if p.is_dir():
            return preview_dir(path)
        return 0

    if p.is_dir():
        return preview_dir(path)
    return preview_file(path)


if __name__ == '__main__':
    raise SystemExit(main())
