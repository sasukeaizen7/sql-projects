"""Run the whole project: download -> load (SQL) -> analyze (SQL) -> visualize (Python)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from toolkit import Project  # noqa: E402

SOURCES = [
    ('https://data.cityofchicago.org/resource/ijzp-q8t2.csv?$limit=500000&$where=year=2024&$select=id,date,primary_type,description,location_description,arrest,domestic,district,community_area', 'crimes_2024.csv'),
    ('https://data.cityofchicago.org/resource/igwz-8jzy.csv?$select=area_numbe,community', 'community_areas.csv'),
]

if __name__ == "__main__":
    import visualize

    Project.here(__file__, SOURCES).run(visualize.main)
