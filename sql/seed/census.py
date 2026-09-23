"""
Ai cause im learning to read XML dumps, I want to know what attributes exist in the rows, and how often they occur.
Survey a Stack Exchange XML dump: which attributes exist, and how often.

Read-only. Produces evidence for dump_schema.py; it makes no decisions itself.

Usage:
    python sql/seed/census.py data/Posts.xml
    python sql/seed/census.py data/Posts.xml data/Users.xml
    python sql/seed/census.py "data/*.xml"
"""

import sys
from collections import Counter
from glob import glob
from pathlib import Path
import xml.etree.ElementTree as ET

ROW_TAG = "row"
PROGRESS_EVERY = 250_000
EXAMPLE_MAX = 60


def census(path):
    """One streaming pass. Returns row count plus per-attribute counts, lengths and examples."""
    rows = 0
    counts = Counter()
    total_len = Counter()
    max_len = {}
    examples = {}

    context = ET.iterparse(path, events=("start", "end"))
    _, root = next(context)

    for event, elem in context:
        if event != "end" or elem.tag != ROW_TAG:
            continue

        rows += 1
        for name, value in elem.attrib.items():      # read before clearing
            counts[name] += 1
            n = len(value)
            total_len[name] += n
            if n > max_len.get(name, -1):
                max_len[name] = n
            if value and name not in examples:
                examples[name] = value

        root.clear()                                 # detach every finished row

        if rows % PROGRESS_EVERY == 0:
            print(f"  ...{rows:,} rows", file=sys.stderr)

    return rows, counts, total_len, max_len, examples


def report(path, rows, counts, total_len, max_len, examples):
    grand = sum(total_len.values())
    print(f"\n{path}")
    print(f"{rows:,} <{ROW_TAG}> elements, {len(counts)} distinct attributes, "
          f"{grand:,} chars of attribute data\n")

    if not rows or not counts:
        print("  (nothing counted -- wrong file, or a different row tag?)")
        return

    width = max((len(name) for name in counts), default=9)
    head = (f"  {'attribute'.ljust(width)}  {'rows':>9}  {'%':>6}  "
            f"{'mean':>6}  {'max':>7}  {'share':>6}  example")
    print(head)
    print("  " + "-" * (len(head) - 2))

    for name, n in counts.items():
        mean = total_len[name] / n
        share = 100.0 * total_len[name] / grand if grand else 0.0
        example = " ".join(examples.get(name, "").split())
        if len(example) > EXAMPLE_MAX:
            example = example[:EXAMPLE_MAX - 3] + "..."
        print(f"  {name.ljust(width)}  {n:>9,}  {100.0 * n / rows:>5.1f}%  "
              f"{mean:>6.1f}  {max_len[name]:>7,}  {share:>5.1f}%  {example}")

def main(argv):
    if not argv:
        print(__doc__)
        return 2

    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    targets = []
    for arg in argv:                  # Windows shells do not expand globs
        targets.extend(sorted(glob(arg)) or [arg])

    status = 0
    for target in targets:
        path = Path(target)
        if not path.is_file():
            print(f"not a file: {path}", file=sys.stderr)
            status = 1
            continue
        try:
            rows, counts, total_len, max_len, examples = census(path)
        except ET.ParseError as exc:
            print(f"{path}: XML parse error: {exc}", file=sys.stderr)
            status = 1
            continue
        report(path, rows, counts, total_len, max_len, examples)
    return status


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))