"""Run every project end to end (download -> load -> analyze -> visualize), or only the ones named.

    python run_all.py                       # all 18 projects
    python run_all.py 01-nyc-taxi-trips     # just one
"""

import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent

if __name__ == "__main__":
    wanted = set(sys.argv[1:])
    projects = [p for p in sorted((ROOT / "projects").iterdir()) if (p / "run.py").exists() and (not wanted or p.name in wanted)]
    failed = []
    for project in projects:
        start = time.perf_counter()
        result = subprocess.run([sys.executable, "run.py"], cwd=project)
        status = "ok" if result.returncode == 0 else "FAILED"
        print(f"==> {project.name}: {status} in {time.perf_counter() - start:.0f}s\n")
        if result.returncode:
            failed.append(project.name)
    print(f"{len(projects) - len(failed)}/{len(projects)} projects succeeded" + (f"; failed: {', '.join(failed)}" if failed else ""))
    sys.exit(1 if failed else 0)
