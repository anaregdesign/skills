#!/usr/bin/env python3
"""Validate one or more JSON files."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="+", help="JSON file paths to validate")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    for raw in args.files:
        path = Path(raw).expanduser().resolve()
        if not path.exists():
            print(f"[ERROR] Not found: {path}")
            return 1
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            print(f"[ERROR] Not UTF-8 text: {path}")
            return 1
        try:
            data = json.loads(text)
        except json.JSONDecodeError as exc:
            print(f"[ERROR] Invalid JSON: {path}: {exc}")
            return 1
        print(f"[OK] {path} ({type(data).__name__})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
