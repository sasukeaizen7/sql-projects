"""Download the raw data of every project (or of the folders given as arguments)."""

import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
from toolkit import Project  # noqa: E402


def load_sources(run_py: Path):
    spec = importlib.util.spec_from_file_location(f"run_{run_py.parent.name.replace('-', '_')}", run_py)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.SOURCES


if __name__ == "__main__":
    wanted = set(sys.argv[1:])
    failed = []
    for run_py in sorted((ROOT / "projects").glob("*/run.py")):
        if wanted and run_py.parent.name not in wanted:
            continue
        print(f"[{run_py.parent.name}]")
        try:
            Project.here(str(run_py), load_sources(run_py)).download()
        except Exception as e:  # keep going; report at the end
            failed.append((run_py.parent.name, str(e)))
            print(f"  FAILED: {e}")
    print("\nfailed:" if failed else "\nall downloads OK", *failed, sep="\n")
