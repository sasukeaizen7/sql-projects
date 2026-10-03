"""Run the whole project: download -> load (SQL) -> analyze (SQL) -> visualize (Python)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from toolkit import Project  # noqa: E402

SOURCES = [
    ('https://files.data.gouv.fr/geo-dvf/latest/csv/2024/departements/75.csv.gz', 'dvf_2024_paris.csv.gz'),
    ('https://files.data.gouv.fr/geo-dvf/latest/csv/2023/departements/75.csv.gz', 'dvf_2023_paris.csv.gz'),
]

if __name__ == "__main__":
    import visualize

    Project.here(__file__, SOURCES).run(visualize.main)
