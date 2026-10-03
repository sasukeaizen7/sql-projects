"""Run the whole project: download -> load (SQL) -> analyze (SQL) -> visualize (Python)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from toolkit import Project  # noqa: E402

SOURCES = [
    ('https://raw.githubusercontent.com/jpatokal/openflights/master/data/airports.dat', 'airports.dat'),
    ('https://raw.githubusercontent.com/jpatokal/openflights/master/data/airlines.dat', 'airlines.dat'),
    ('https://raw.githubusercontent.com/jpatokal/openflights/master/data/routes.dat', 'routes.dat'),
]

if __name__ == "__main__":
    import visualize

    Project.here(__file__, SOURCES).run(visualize.main)
