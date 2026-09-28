"""Load staging CSVs into Postgres with COPY FROM STDIN.

Column lists come from dump_schema.py, so the COPY statement cannot disagree with
what parse_dump.py wrote.

    python sql/seed/load_dump.py Posts
    python sql/seed/load_dump.py --all
    python sql/seed/load_dump.py Posts --print-sql

The whole run is one transaction: every table lands, or nothing changes.

Connection comes from PGHOST, PGPORT, PGDATABASE, PGUSER and PGPASSWORD, falling
back to localhost:5432/stackexchange as postgres, prompting for the password if
PGPASSWORD is unset. No credentials in the repo.
lawd im learning through AI
"""

import argparse
import os
import re
import sys
from getpass import getpass
from pathlib import Path

import psycopg2

import dump_schema

REPO_ROOT = Path(__file__).resolve().parents[2]


def connection_settings():
    return {
        "host": os.environ.get("PGHOST", "localhost"),
        "port": os.environ.get("PGPORT", "5432"),
        "dbname": os.environ.get("PGDATABASE", "stackexchange"),
        "user": os.environ.get("PGUSER", "postgres"),
        "password": os.environ.get("PGPASSWORD") or getpass("Postgres password: "),
    }


def copy_targets(table_key, schema):
    """[(qualified sql table, csv filename, [sql column names])] for one contract entry."""
    spec = dump_schema.TABLES[table_key]

    targets = [(
        f"{schema}.{spec["table"]}",
        f"{spec['table']}.csv",
        [dump_schema.sql_name(table_key, c) for c in spec["columns"]],
    )]

    offload = spec.get("offload")
    if offload:
        cols = [offload["key"]] + offload["columns"]
        targets.append((
            f"{schema}.{offload['table']}",
            f"{offload['table']}.csv",
            [dump_schema.sql_name(table_key, c) for c in cols],
        ))

    return targets


def copy_sql(table, columns):
    """Naming every column explicitly is what makes a contract mismatch fail loudly
    instead of shifting data one column to the left."""
    column_list = ",\n    ".join(columns)
    return (
        f"COPY {table} (\n    {column_list}\n)\n"
        f"FROM STDIN WITH (FORMAT csv, NULL '')"
    )


def load(cursor, csv_dir, table_key, schema):
    loaded = []
    for table, csv_name, columns in copy_targets(table_key, schema):
        path = csv_dir / csv_name
        if not path.is_file():
            raise SystemExit(f"missing CSV: {path}\nRun parse_dump.py first.")

        cursor.execute(f"TRUNCATE {table}")
        with open(path, "r", encoding="utf-8", newline="") as handle:
            cursor.copy_expert(copy_sql(table, columns), handle)

        cursor.execute(f"SELECT count(*) FROM {table}")
        loaded.append((table, cursor.fetchone()[0]))

    return loaded


def main(argv=None):
    ap = argparse.ArgumentParser(description="Load staging CSVs into Postgres.")
    ap.add_argument("table", nargs="?", help="table key from dump_schema, e.g. Posts")
    ap.add_argument("--all", action="store_true", help="load every table in the contract")
    ap.add_argument("--site", default="coffee", help="subfolder of data/ (default: coffee)")
    ap.add_argument("--csv-dir", help="override the directory holding the CSVs")
    ap.add_argument("--print-sql", action="store_true",
                    help="print the COPY statements and exit without connecting")
    args = ap.parse_args(argv)

    if args.all == bool(args.table):
        ap.error("give exactly one of: a table name, or --all")

    keys = list(dump_schema.TABLES) if args.all else [args.table]

    missing = [k for k in keys if k not in dump_schema.TABLES]
    if missing:
        ap.error(f"not in the contract: {', '.join(missing)}. "
                 f"Known: {', '.join(dump_schema.TABLES)}")

    schema = args.site.lower()
    if not re.fullmatch(r"[a-z][a-z0-9_]*", schema):
        ap.error(f"invalid schema name: {schema!r}")

    if args.print_sql:
        for key in keys:
            for table, _, columns in copy_targets(key, schema):
                print(copy_sql(table, columns) + ";\n")
        return 0

    csv_dir = Path(args.csv_dir) if args.csv_dir else REPO_ROOT / "data" / args.site

    conn = psycopg2.connect(**connection_settings())
    try:
        with conn:                          # commits on success, rolls back on error
            with conn.cursor() as cursor:
                cursor.execute(f"SET search_path TO {schema}")
                for key in keys:
                    for table, count in load(cursor, csv_dir, key, schema):
                        print(f"{table:32} {count:>9,}")
    finally:
        conn.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())