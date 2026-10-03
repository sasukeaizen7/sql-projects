"""PostgreSQL side of a project: copy the DuckDB tables into Postgres, then benchmark indexes.

DuckDB is a columnar engine that scans everything fast and barely needs indexes. Postgres is a
row store where indexing is the main performance lever, so the indexing work happens here.

SQL conventions
---------------
* ``sql/03_postgres_schema.sql`` creates the Postgres tables with their constraints (primary,
  foreign and unique keys, CHECKs) but no secondary indexes. Every table it creates is filled from
  the DuckDB table of the same name, in creation order (parents before children). A line
  ``-- source: <table> = <DuckDB query>`` overrides the DuckDB query for one table, e.g. to store
  rows in time order so a BRIN index works.
* ``sql/04_index_benchmarks.sql`` holds named queries, each with the index(es) under test::

      -- name: zone_time_window
      -- Trips from one zone in a two-hour window.
      -- index: CREATE INDEX trips_zone_time ON trips (pickup_zone_id, pickup_at)
      SELECT ...;

  Every query is timed with only the constraint indexes (median of several EXPLAIN ANALYZE runs
  after a warm-up), then again after creating its indexes. Its result must be identical both
  times. Indexes are dropped before the next query, so every benchmark starts from the same
  baseline. A query without ``-- index:`` lines is timed once, as a reference.

Output: ``results/index_benchmark.csv`` and the before/after plans in ``results/plans/<name>.txt``.

Connection: ``PG_DSN`` if set, else ``postgresql://portfolio@localhost:5433/portfolio``. If nothing
answers there, a private cluster is created in ``.pgdata/`` (gitignored, trust auth, localhost
only) with the PostgreSQL binaries found on PATH or in the default install folders, and left
running for the next project. ``python -m toolkit.postgres stop`` shuts it down.
"""

from __future__ import annotations

import glob
import hashlib
import json
import os
import re
import shutil
import statistics
import subprocess
import sys
import time
from pathlib import Path
from typing import TYPE_CHECKING

import pandas as pd

if TYPE_CHECKING:
    from .pipeline import Project

ROOT = Path(__file__).resolve().parents[1]
PGDATA = ROOT / ".pgdata"
DEFAULT_DSN = "postgresql://portfolio@localhost:5433/portfolio"
RUNS = 5  # timed runs per measurement, after one warm-up run

NAME_RE = re.compile(r"^--\s*name:\s*([a-z0-9_]+)\s*$", re.MULTILINE)
SOURCE_RE = re.compile(r"^--\s*source:\s*(\w+)\s*=\s*(.+)$", re.MULTILINE)
INDEX_RE = re.compile(r"^--\s*index:\s*(.+?)\s*;?\s*$", re.MULTILINE)


class PostgresUnavailable(RuntimeError):
    pass


# --- server ---------------------------------------------------------------------------------
def _pg_bin(tool: str) -> str | None:
    found = shutil.which(tool)
    if found:
        return found
    patterns = [r"C:\Program Files\PostgreSQL\*\bin", "/usr/lib/postgresql/*/bin",
                "/opt/homebrew/opt/postgresql@*/bin", "/Applications/Postgres.app/Contents/Versions/*/bin"]
    for pattern in patterns:
        for d in sorted(glob.glob(pattern), reverse=True):  # newest version first
            exe = Path(d) / (tool + (".exe" if os.name == "nt" else ""))
            if exe.exists():
                return str(exe)
    return None


def _try_connect(dsn: str):
    import psycopg
    try:
        return psycopg.connect(dsn, autocommit=True, connect_timeout=3)
    except psycopg.OperationalError:
        return None


def _start_local_cluster() -> None:
    initdb, pg_ctl = _pg_bin("initdb"), _pg_bin("pg_ctl")
    if not (initdb and pg_ctl):
        raise PostgresUnavailable("no PostgreSQL server on localhost:5433 and no PostgreSQL binaries found "
                                  "(install PostgreSQL, run `docker compose up -d`, or set PG_DSN)")
    quiet = {"stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL}
    if not (PGDATA / "PG_VERSION").exists():
        print("  creating a local PostgreSQL cluster in .pgdata/")
        subprocess.run([initdb, "-D", str(PGDATA), "-U", "portfolio", "--auth=trust", "-E", "UTF8", "--no-locale"],
                       check=True, **quiet)
    print("  starting local PostgreSQL on port 5433")
    subprocess.run([pg_ctl, "-D", str(PGDATA), "-l", str(PGDATA / "server.log"), "-w",
                    "-o", "-p 5433 -c listen_addresses=localhost", "start"], check=True, **quiet)
    with _try_connect(DEFAULT_DSN.rsplit("/", 1)[0] + "/postgres") as con:
        if not con.execute("select 1 from pg_database where datname = 'portfolio'").fetchone():
            con.execute("create database portfolio")


def connect():
    """Connect to PG_DSN, or to the local cluster (started on demand)."""
    dsn = os.environ.get("PG_DSN")
    if dsn:
        con = _try_connect(dsn)
        if con is None:
            raise PostgresUnavailable(f"cannot connect to PG_DSN={dsn}")
        return con
    con = _try_connect(DEFAULT_DSN)
    if con is None:
        _start_local_cluster()
        con = _try_connect(DEFAULT_DSN)
    if con is None:
        raise PostgresUnavailable(f"PostgreSQL did not come up, see {PGDATA / 'server.log'}")
    return con


def stop_local_cluster() -> None:
    pg_ctl = _pg_bin("pg_ctl")
    if pg_ctl and (PGDATA / "postmaster.pid").exists():
        subprocess.run([pg_ctl, "-D", str(PGDATA), "-m", "fast", "stop"], check=False)


# --- load -----------------------------------------------------------------------------------
def schema_name(project: "Project") -> str:
    """'01-nyc-taxi-trips' -> 'nyc_taxi_trips' (one Postgres schema per project)."""
    return re.sub(r"^\d+_", "", project.root.name.replace("-", "_"))


def load(project: "Project", con) -> None:
    schema = schema_name(project)
    ddl = (project.root / "sql" / "03_postgres_schema.sql").read_text(encoding="utf-8")
    sources = {t: q.strip().rstrip(";") for t, q in SOURCE_RE.findall(ddl)}
    # Skip the copy when neither the schema file nor the DuckDB warehouse changed since the last load.
    version = hashlib.sha1(f"{ddl}{project.db_path.stat().st_mtime_ns}".encode()).hexdigest()
    loaded = con.execute("SELECT obj_description(oid, 'pg_namespace') FROM pg_namespace WHERE nspname = %s",
                         (schema,)).fetchone()
    if loaded and loaded[0] == version:
        print("  postgres: tables up to date, reusing them")
        return
    con.execute(f"DROP SCHEMA IF EXISTS {schema} CASCADE")
    con.execute(f"CREATE SCHEMA {schema}")
    con.execute(f"SET search_path = {schema}, public")
    con.execute(ddl)
    tables = [r[0] for r in con.execute(
        "SELECT relname FROM pg_class WHERE relnamespace = %s::regnamespace AND relkind = 'r' ORDER BY oid",
        (schema,)).fetchall()]
    t0 = time.perf_counter()
    with project.connect(read_only=True) as duck:
        for table in tables:
            cols = [r[0] for r in con.execute(
                "SELECT column_name FROM information_schema.columns WHERE table_schema = %s AND table_name = %s "
                "ORDER BY ordinal_position", (schema, table)).fetchall()]
            query = sources.get(table, f"SELECT {', '.join(cols)} FROM {table}")
            csv = project.data / f"pg_{table}.csv"
            duck.execute(f"COPY ({query}) TO '{csv.as_posix()}' (HEADER, DELIMITER ',')")
            with con.cursor() as cur, cur.copy(f"COPY {table} ({', '.join(cols)}) FROM STDIN (FORMAT csv, HEADER)") as cp, \
                    open(csv, "rb") as f:
                while block := f.read(1 << 20):
                    cp.write(block)
            csv.unlink()
            con.execute(f"VACUUM (ANALYZE) {table}")  # fresh stats + visibility map (index-only scans)
    con.execute(f"COMMENT ON SCHEMA {schema} IS '{version}'")
    sizes = con.execute(
        "SELECT relname, reltuples::bigint, pg_size_pretty(pg_total_relation_size(oid)) FROM pg_class "
        "WHERE relnamespace = %s::regnamespace AND relkind = 'r' ORDER BY oid", (schema,)).fetchall()
    print(f"  postgres: loaded in {time.perf_counter() - t0:.1f}s: "
          + ", ".join(f"{n} (~{r:,} rows, {s})" for n, r, s in sizes))


# --- benchmark ------------------------------------------------------------------------------
def _plan_nodes(node: dict, out: list[str]) -> list[str]:
    kind = ("Parallel " if node.get("Parallel Aware") else "") + node["Node Type"]
    if "Index Name" in node:
        kind += f" using {node['Index Name']}"
    elif "Relation Name" in node and "Scan" in kind:
        kind += f" on {node['Relation Name']}"
    if kind not in out:
        out.append(kind)
    for child in node.get("Plans", []):
        _plan_nodes(child, out)
    return out


def _scans(nodes: list[str]) -> str:
    """The access paths of a plan (how each table was read), e.g. 'Index Only Scan using trips_zone_cover'."""
    scans = [n for n in nodes if "Scan" in n and not n.startswith(("Subquery", "CTE", "Function", "Values", "WorkTable"))]
    return " + ".join(scans) or nodes[0]


def _measure(con, query: str) -> tuple[float, str, str]:
    """Median execution time (ms) over RUNS runs after a warm-up, the scan summary and the text plan."""
    times, plan = [], None
    for i in range(RUNS + 1):
        plan = con.execute(f"EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) {query}").fetchone()[0]
        if isinstance(plan, str):
            plan = json.loads(plan)
        if i:
            times.append(plan[0]["Execution Time"])
    text = "\n".join(r[0] for r in con.execute(f"EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) {query}").fetchall())
    return statistics.median(times), _scans(_plan_nodes(plan[0]["Plan"], [])), text


def _secondary_indexes(con, schema: str) -> list[str]:
    return [r[0] for r in con.execute(
        "SELECT i.relname FROM pg_index x JOIN pg_class i ON i.oid = x.indexrelid "
        "JOIN pg_class t ON t.oid = x.indrelid "
        "LEFT JOIN pg_constraint c ON c.conindid = x.indexrelid "
        "WHERE t.relnamespace = %s::regnamespace AND c.oid IS NULL", (schema,)).fetchall()]


def _index_name(ddl: str) -> str:
    m = re.search(r"INDEX\s+(?:IF NOT EXISTS\s+)?(\w+)\s+ON", ddl, re.IGNORECASE)
    if not m:
        raise ValueError(f"benchmark indexes must be named: {ddl}")
    return m.group(1)


def benchmark(project: "Project", con) -> pd.DataFrame:
    schema = schema_name(project)
    text = (project.root / "sql" / "04_index_benchmarks.sql").read_text(encoding="utf-8")
    parts = NAME_RE.split(text)
    plans_dir = project.results / "plans"
    shutil.rmtree(plans_dir, ignore_errors=True)
    plans_dir.mkdir(parents=True)
    con.execute(f"SET search_path = {schema}, public")
    con.execute("SET jit = off")  # JIT compile time is noise at this scale
    tables = [r[0] for r in con.execute(
        "SELECT relname FROM pg_class WHERE relnamespace = %s::regnamespace AND relkind = 'r'", (schema,)).fetchall()]
    rows = []
    for i in range(1, len(parts), 2):
        name, body = parts[i], parts[i + 1]
        indexes = INDEX_RE.findall(body)
        comments = [l.lstrip("- ").strip() for l in body.strip().splitlines()
                    if l.startswith("--") and not INDEX_RE.match(l)]
        question = comments[0] if comments else ""
        query = "\n".join(l for l in body.strip().splitlines() if not l.startswith("--")).strip().rstrip(";")
        for idx in _secondary_indexes(con, schema):
            con.execute(f"DROP INDEX {idx}")
        con.execute("ANALYZE " + ", ".join(tables))
        expected = con.execute(query).fetchall()
        before_ms, before_scan, before_plan = _measure(con, query)
        row = {"name": name, "question": question, "indexes": "; ".join(indexes), "rows": len(expected),
               "before_ms": round(before_ms, 2), "before_plan": before_scan}
        plan_text = f"-- {name}: {question}\n\n=== BEFORE (constraint indexes only) ===\n{before_plan}\n"
        if indexes:
            t0 = time.perf_counter()
            for ddl in indexes:
                con.execute(ddl)
            build_s = time.perf_counter() - t0
            con.execute("ANALYZE " + ", ".join(tables))  # statistics for expression indexes
            size = sum(con.execute("SELECT pg_relation_size(%s::regclass)", (_index_name(d),)).fetchone()[0]
                       for d in indexes)
            if con.execute(query).fetchall() != expected:
                raise AssertionError(f"{name}: the result changed after creating the index")
            after_ms, after_scan, after_plan = _measure(con, query)
            row.update(after_ms=round(after_ms, 2), after_plan=after_scan, speedup=round(before_ms / after_ms, 1),
                       index_mb=round(size / 1e6, 2), build_s=round(build_s, 2))
            plan_text += f"\n=== AFTER: {'; '.join(indexes)} ===\n{after_plan}\n"
        (plans_dir / f"{name}.txt").write_text(plan_text, encoding="utf-8")
        rows.append(row)
        after = f"{row['after_ms']:>9.2f} ms  x{row['speedup']:<7} {row['after_plan']}" if indexes else "(reference)"
        print(f"  {name:<28} {before_ms:>9.2f} ms -> {after}")
    for idx in _secondary_indexes(con, schema):
        con.execute(f"DROP INDEX {idx}")
    df = pd.DataFrame(rows)
    df.to_csv(project.results / "index_benchmark.csv", index=False)
    return df


def run(project: "Project") -> None:
    try:
        con = connect()
    except PostgresUnavailable as e:
        print(f"  skipped: {e}")
        return
    with con:
        load(project, con)
        benchmark(project, con)


if __name__ == "__main__":
    if sys.argv[1:] == ["stop"]:
        stop_local_cluster()
    else:
        print("usage: python -m toolkit.postgres stop")
