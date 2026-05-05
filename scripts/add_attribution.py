#!/usr/bin/env python3
"""Insert "Author: Holden Leslie-Bole, 2026" line at the end of each
script's leading help-comment block. Idempotent: skips files that
already contain "Holden Leslie-Bole".

Usage: python scripts/add_attribution.py [--dry-run]
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ATTR = "% Author: Holden Leslie-Bole, 2026"

EXCLUDE_DIRS = {"outputs", "raw_cache", ".git", "node_modules"}

def find_help_end(lines):
    """Return the 0-based index of the last line of the leading
    help-comment block (contiguous % lines starting at line 0 or
    line 1 if first line is a function decl). Returns -1 if no
    help block found."""
    if not lines:
        return -1
    start = 0
    if lines[0].lstrip().startswith("function "):
        start = 1
    # Skip a single blank line right after function decl
    while start < len(lines) and lines[start].strip() == "":
        start += 1
    # Walk forward through % lines
    end = start - 1
    i = start
    while i < len(lines) and lines[i].lstrip().startswith("%"):
        end = i
        i += 1
    return end

def process_file(path: Path, dry_run: bool):
    text = path.read_text()
    if "Holden Leslie-Bole" in text:
        return "skip-already-has"
    lines = text.splitlines(keepends=True)
    end = find_help_end(lines)
    if end < 0:
        return "skip-no-help-block"
    insertion = ATTR + "\n"
    # If line at end doesn't end with newline, fix that
    if not lines[end].endswith("\n"):
        lines[end] += "\n"
    new_lines = lines[:end+1] + [insertion] + lines[end+1:]
    new_text = "".join(new_lines)
    if dry_run:
        return f"would-insert-after-line-{end+1}"
    path.write_text(new_text)
    return f"inserted-after-line-{end+1}"

def main():
    dry = "--dry-run" in sys.argv
    files = []
    for p in ROOT.rglob("*.m"):
        rel = p.relative_to(ROOT)
        if any(part in EXCLUDE_DIRS for part in rel.parts):
            continue
        files.append(p)
    print(f"Found {len(files)} .m files (excluding {EXCLUDE_DIRS}).")
    counts = {}
    for p in sorted(files):
        result = process_file(p, dry)
        counts[result] = counts.get(result, 0) + 1
        if not result.startswith("skip-already-has"):
            print(f"  {result}: {p.relative_to(ROOT)}")
    print("\nSummary:")
    for k, v in counts.items():
        print(f"  {k}: {v}")

if __name__ == "__main__":
    main()
