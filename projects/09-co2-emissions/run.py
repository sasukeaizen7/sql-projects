"""Run the whole project: download -> load (SQL) -> analyze (SQL) -> visualize (Python)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from toolkit import Project  # noqa: E402

SOURCES = [
    ('https://raw.githubusercontent.com/owid/co2-data/master/owid-co2-data.csv', 'owid-co2-data.csv'),
]

if __name__ == "__main__":
    import visualize

    Project.here(__file__, SOURCES).run(visualize.main)
