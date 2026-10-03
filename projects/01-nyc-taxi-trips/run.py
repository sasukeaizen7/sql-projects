"""Run the whole project: download -> load (SQL) -> analyze (SQL) -> visualize (Python)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from toolkit import Project  # noqa: E402

SOURCES = [
    ('https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2024-01.parquet', 'yellow_tripdata_2024-01.parquet'),
    ('https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv', 'taxi_zone_lookup.csv'),
]

if __name__ == "__main__":
    import visualize

    Project.here(__file__, SOURCES).run(visualize.main)
