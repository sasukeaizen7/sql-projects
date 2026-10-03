"""Run the whole project: download -> load (SQL) -> analyze (SQL) -> visualize (Python)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from toolkit import Project  # noqa: E402

SOURCES = [
    ('https://data.ratp.fr/api/explore/v2.1/catalog/datasets/trafic-annuel-entrant-par-station-du-reseau-ferre/exports/csv?delimiter=%3B', 'ratp_traffic_2013.csv'),
    ('https://data.ratp.fr/api/explore/v2.1/catalog/datasets/trafic-annuel-entrant-par-station-du-reseau-ferre-2014/exports/csv?delimiter=%3B', 'ratp_traffic_2014.csv'),
    ('https://data.ratp.fr/api/explore/v2.1/catalog/datasets/trafic-annuel-entrant-par-station-du-reseau-ferre-2015/exports/csv?delimiter=%3B', 'ratp_traffic_2015.csv'),
    ('https://data.ratp.fr/api/explore/v2.1/catalog/datasets/trafic-annuel-entrant-par-station-du-reseau-ferre-2016/exports/csv?delimiter=%3B', 'ratp_traffic_2016.csv'),
    ('https://data.ratp.fr/api/explore/v2.1/catalog/datasets/trafic-annuel-entrant-par-station-du-reseau-ferre-2017/exports/csv?delimiter=%3B', 'ratp_traffic_2017.csv'),
    ('https://data.ratp.fr/api/explore/v2.1/catalog/datasets/trafic-annuel-entrant-par-station-du-reseau-ferre-2018/exports/csv?delimiter=%3B', 'ratp_traffic_2018.csv'),
    ('https://data.ratp.fr/api/explore/v2.1/catalog/datasets/trafic-annuel-entrant-par-station-du-reseau-ferre-2019/exports/csv?delimiter=%3B', 'ratp_traffic_2019.csv'),
    ('https://data.ratp.fr/api/explore/v2.1/catalog/datasets/trafic-annuel-entrant-par-station-du-reseau-ferre-2020/exports/csv?delimiter=%3B', 'ratp_traffic_2020.csv'),
    ('https://data.ratp.fr/api/explore/v2.1/catalog/datasets/trafic-annuel-entrant-par-station-du-reseau-ferre-2021/exports/csv?delimiter=%3B', 'ratp_traffic_2021.csv'),
]

if __name__ == "__main__":
    import visualize

    Project.here(__file__, SOURCES).run(visualize.main)
