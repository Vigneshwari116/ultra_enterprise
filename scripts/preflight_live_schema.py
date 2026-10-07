#!/usr/bin/env python3
"""Read-only live VPS schema preflight for historical seed (no writes)."""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Run live schema preflight SQL")
    parser.add_argument(
        "--database-url",
        default=os.environ.get("DATABASE_URL", ""),
        help="PostgreSQL connection string",
    )
    args = parser.parse_args()
    if not args.database_url:
        print("ERROR: DATABASE_URL or --database-url is required", file=sys.stderr)
        return 1

    import psycopg

    sql_path = Path(__file__).resolve().parent / "preflight_live_schema.sql"
    sql = sql_path.read_text()

    with psycopg.connect(args.database_url) as conn:
        with conn.cursor() as cur:
            for statement in _split_sql(sql):
                if not statement.strip():
                    continue
                if statement.strip().startswith("\\echo"):
                    print(statement.strip()[6:].strip().strip("'"))
                    continue
                cur.execute(statement)
                if cur.description:
                    rows = cur.fetchall()
                    cols = [d.name for d in cur.description]
                    print(" | ".join(cols))
                    print("-" * 72)
                    for row in rows:
                        print(" | ".join("" if v is None else str(v) for v in row))
                    print()
    return 0


def _split_sql(sql: str) -> list[str]:
    parts: list[str] = []
    buf: list[str] = []
    for line in sql.splitlines():
        if line.startswith("\\echo"):
            if buf:
                parts.append("\n".join(buf))
                buf = []
            parts.append(line)
            continue
        buf.append(line)
        if line.rstrip().endswith(";"):
            parts.append("\n".join(buf))
            buf = []
    if buf:
        parts.append("\n".join(buf))
    return parts


if __name__ == "__main__":
    raise SystemExit(main())
