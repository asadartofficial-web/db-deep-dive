"""Parse Stack Exchange dump tables into staging CSVs.

Reads the column contract from dump_schema.py and knows no attribute names of its
own. Streams the XML, so memory stays flat whatever the dump size.

    python sql/seed/parse_dump.py Posts
    python sql/seed/parse_dump.py --all
    python sql/seed/parse_dump.py Posts --site coffee
    python sql/seed/parse_dump.py Posts --source data/sample_posts.xml --out-dir data
 AI has been used cause im dumb and learning smh.
Writes data/<site>/<staging_table>.csv -- two files for a table whose contract
offloads wide text. Exits non-zero on any attribute the contract does not classify.
"""

import argparse
import csv
import sys
from contextlib import ExitStack
from pathlib import Path
import xml.etree.ElementTree as ET

import dump_schema

ROW_TAG = "row"
PROGRESS_EVERY = 250_000
REPO_ROOT = Path(__file__).resolve().parents[2]


def parse(table_key, source, out_dir):
    """Stream one XML file into its staging CSV(s).

    Returns (rows read, {csv filename: rows written}).
    """
    spec = dump_schema.TABLES[table_key]
    offload = spec.get("offload")
    known = dump_schema.classified(table_key)

    rows_read = 0
    written = {}

    with ExitStack() as stack:
        targets = []

        main_name = f"{spec['table']}.csv"
        main_file = stack.enter_context(
            open(out_dir / main_name, "w", newline="", encoding="utf-8")
        )
        targets.append((main_name, csv.writer(main_file), spec["columns"], False))
        written[main_name] = 0

        if offload:
            text_name = f"{offload['table']}.csv"
            text_file = stack.enter_context(
                open(out_dir / text_name, "w", newline="", encoding="utf-8")
            )
            text_cols = [offload["key"]] + offload["columns"]
            targets.append((text_name, csv.writer(text_file), text_cols, True))
            written[text_name] = 0

        context = ET.iterparse(source, events=("start", "end"))
        _, root = next(context)

        for event, elem in context:
            if event != "end" or elem.tag != ROW_TAG:
                continue

            attrib = elem.attrib               # read before clearing

            unknown = set(attrib) - known
            if unknown:
                raise SystemExit(
                    f"{source.name}: row Id={attrib.get('Id', '?')} carries "
                    f"unclassified attribute(s): {', '.join(sorted(unknown))}. "
                    f"Add each to columns, offload or ignore in dump_schema.py."
                )

            rows_read += 1
            for name, writer, cols, is_offload in targets:
                values = [attrib.get(c, "") for c in cols]
                if is_offload and not any(values[1:]):
                    continue                   # no text on this row -- no side row
                writer.writerow(values)
                written[name] += 1

            root.clear()                       # detach every finished row

            if rows_read % PROGRESS_EVERY == 0:
                print(f"  ...{rows_read:,} rows", file=sys.stderr)

    return rows_read, written


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Parse a Stack Exchange dump table into staging CSVs."
    )
    ap.add_argument("table", nargs="?", help="table key from dump_schema, e.g. Posts")
    ap.add_argument("--all", action="store_true", help="parse every table in the contract")
    ap.add_argument("--site", default="coffee", help="subfolder of data/ (default: coffee)")
    ap.add_argument("--source", help="override the input XML path")
    ap.add_argument("--out-dir", help="override the output directory")
    args = ap.parse_args(argv)

    if args.all == bool(args.table):
        ap.error("give exactly one of: a table name, or --all")

    keys = list(dump_schema.TABLES) if args.all else [args.table]

    missing = [k for k in keys if k not in dump_schema.TABLES]
    if missing:
        ap.error(f"not in the contract: {', '.join(missing)}. "
                 f"Known: {', '.join(dump_schema.TABLES)}")

    if args.source and len(keys) > 1:
        ap.error("--source only makes sense with a single table")

    site_dir = REPO_ROOT / "data" / args.site
    out_dir = Path(args.out_dir) if args.out_dir else site_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    for key in keys:
        source = Path(args.source) if args.source else site_dir / dump_schema.source_file(key)
        if not source.is_file():
            print(f"missing: {source}", file=sys.stderr)
            return 1

        rows, written = parse(key, source, out_dir)
        detail = ", ".join(f"{name} <- {n:,}" for name, n in written.items())
        print(f"{key}: {rows:,} rows read; {detail}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())