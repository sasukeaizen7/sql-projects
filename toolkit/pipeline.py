"""Download -> load -> analyze, driven by plain SQL files.

SQL conventions
---------------
* ``sql/01_load.sql`` builds tables from the raw files in ``data/`` (run as one script).
* ``sql/02_analysis.sql`` holds the questions. Each query starts with a marker line::

      -- name: top_zones
      -- Which pickup zones generate the most revenue?
      SELECT ...;

  Every named query is executed and its result saved to ``results/<name>.csv``,
  which the visualizations and the README read.
"""

from __future__ import annotations

import gzip
import re
import shutil
import sys
import time
import zipfile
from dataclasses import dataclass, field
from pathlib import Path

import duckdb
import pandas as pd
import requests

USER_AGENT = "sql-portfolio/1.0 (educational data analysis; +https://github.com)"
NAME_RE = re.compile(r"^--\s*name:\s*([a-z0-9_]+)\s*$", re.MULTILINE)


@dataclass
class Source:
    url: str
    filename: str
    unzip: bool = False  # extract a .zip archive next to the file
    gunzip: bool = False  # decompress a .gz file to `filename` without the .gz suffix


@dataclass
class Project:
    root: Path
    sources: list[Source] = field(default_factory=list)

    @classmethod
    def here(cls, file: str, sources: list[tuple] | list[Source] = ()) -> "Project":
        srcs = [s if isinstance(s, Source) else Source(*s) for s in sources]
        return cls(Path(file).resolve().parent, srcs)

    # --- paths ----------------------------------------------------------------
    @property
    def data(self) -> Path:
        return self.root / "data"

    @property
    def results(self) -> Path:
        return self.root / "results"

    @property
    def images(self) -> Path:
        return self.root / "images"

    @property
    def db_path(self) -> Path:
        return self.data / "warehouse.duckdb"

    # --- step 1: download ----------------------------------------------------------
    def download(self) -> None:
        self.data.mkdir(exist_ok=True)
        for src in self.sources:
            dest = self.data / src.filename
            if not dest.exists():
                _fetch(src.url, dest)
            if src.unzip:
                marker = dest.with_suffix(dest.suffix + ".extracted")
                if not marker.exists():
                    with zipfile.ZipFile(dest) as zf:
                        zf.extractall(self.data)
                    marker.touch()
            if src.gunzip:
                out = dest.with_suffix("")
                if not out.exists():
                    with gzip.open(dest, "rb") as fin, open(out, "wb") as fout:
                        shutil.copyfileobj(fin, fout)

    # --- step 2 + 3: load and analyze ---------------------------------------------------------
    def connect(self, read_only: bool = False) -> duckdb.DuckDBPyConnection:
        return duckdb.connect(str(self.db_path), read_only=read_only)

    def load(self) -> None:
        sql = (self.root / "sql" / "01_load.sql").read_text(encoding="utf-8")
        with self.connect() as con, _cwd(self.root):
            t = time.perf_counter()
            con.execute(sql)
            tables = con.execute(
                "select table_name, estimated_size from duckdb_tables() order by table_name"
            ).fetchall()
            print(f"  loaded in {time.perf_counter() - t:.1f}s: " + ", ".join(f"{n} (~{s:,} rows)" for n, s in tables))

    def analyze(self) -> dict[str, pd.DataFrame]:
        text = (self.root / "sql" / "02_analysis.sql").read_text(encoding="utf-8")
        self.results.mkdir(exist_ok=True)
        out: dict[str, pd.DataFrame] = {}
        with self.connect(read_only=True) as con, _cwd(self.root):
            for name, query in split_named(text):
                df = con.execute(query).df()
                df.to_csv(self.results / f"{name}.csv", index=False)
                out[name] = df
                print(f"  {name}: {len(df)} rows")
        return out

    def result(self, name: str) -> pd.DataFrame:
        return pd.read_csv(self.results / f"{name}.csv")

    def run(self, visualize=None) -> None:
        print(f"[{self.root.name}]")
        print(" 1/4 download"); self.download()
        print(" 2/4 load"); self.load()
        print(" 3/4 analyze"); self.analyze()
        if visualize:
            print(" 4/4 visualize")
            self.images.mkdir(exist_ok=True)
            visualize(self)


def split_named(text: str) -> list[tuple[str, str]]:
    """Split an analysis file into (name, query) pairs on `-- name:` markers."""
    parts = NAME_RE.split(text)
    pairs = []
    for i in range(1, len(parts), 2):
        query = parts[i + 1].strip().rstrip(";").strip()
        if query:
            pairs.append((parts[i], query))
    if not pairs:
        raise ValueError("no `-- name:` queries found")
    return pairs


def _fetch(url: str, dest: Path, attempts: int = 3) -> None:
    tmp = dest.with_suffix(dest.suffix + ".part")
    for attempt in range(1, attempts + 1):
        try:
            with requests.get(url, stream=True, timeout=120, headers={"User-Agent": USER_AGENT}) as r:
                r.raise_for_status()
                size = 0
                with open(tmp, "wb") as f:
                    for chunk in r.iter_content(1 << 20):
                        f.write(chunk)
                        size += len(chunk)
            tmp.replace(dest)
            print(f"  downloaded {dest.name} ({size / 1e6:.1f} MB)")
            return
        except requests.RequestException as e:
            print(f"  attempt {attempt} failed for {dest.name}: {e}", file=sys.stderr)
            time.sleep(3 * attempt)
    raise RuntimeError(f"could not download {url}")


class _cwd:
    """Run SQL with the project folder as working directory, so 'data/x.csv' paths resolve."""

    def __init__(self, path: Path):
        self.path, self.prev = path, None

    def __enter__(self):
        import os
        self.prev = os.getcwd()
        os.chdir(self.path)

    def __exit__(self, *exc):
        import os
        os.chdir(self.prev)
