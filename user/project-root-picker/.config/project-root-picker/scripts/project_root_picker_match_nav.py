#!/usr/bin/env python
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

MATCH_HELPER = Path.home() / '.config/project-root-picker/scripts/project_root_picker_match.py'


def extract_path(row: str) -> str:
    parts = row.split('\t')
    return parts[1] if len(parts) >= 2 else ''


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument('state_file')
    parser.add_argument('delta', type=int)
    parser.add_argument('query')
    parser.add_argument('row')
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    path = extract_path(args.row)
    if not path or not args.query or not Path(path).is_file():
        return 0
    try:
        return subprocess.call([
            str(MATCH_HELPER),
            'nav',
            '--state', args.state_file,
            '--query', args.query,
            '--path', path,
            '--delta', str(args.delta),
        ])
    except OSError:
        return 0


if __name__ == '__main__':
    raise SystemExit(main())
