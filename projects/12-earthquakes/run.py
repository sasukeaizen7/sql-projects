"""Run the whole project: download -> load (SQL) -> analyze (SQL) -> visualize (Python)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from toolkit import Project  # noqa: E402

SOURCES = [
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2000-01-01&endtime=2001-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2000.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2001-01-01&endtime=2002-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2001.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2002-01-01&endtime=2003-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2002.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2003-01-01&endtime=2004-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2003.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2004-01-01&endtime=2005-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2004.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2005-01-01&endtime=2006-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2005.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2006-01-01&endtime=2007-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2006.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2007-01-01&endtime=2008-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2007.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2008-01-01&endtime=2009-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2008.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2009-01-01&endtime=2010-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2009.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2010-01-01&endtime=2011-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2010.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2011-01-01&endtime=2012-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2011.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2012-01-01&endtime=2013-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2012.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2013-01-01&endtime=2014-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2013.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2014-01-01&endtime=2015-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2014.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2015-01-01&endtime=2016-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2015.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2016-01-01&endtime=2017-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2016.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2017-01-01&endtime=2018-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2017.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2018-01-01&endtime=2019-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2018.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2019-01-01&endtime=2020-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2019.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2020-01-01&endtime=2021-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2020.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2021-01-01&endtime=2022-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2021.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2022-01-01&endtime=2023-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2022.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2023-01-01&endtime=2024-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2023.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2024-01-01&endtime=2025-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2024.csv'),
    ('https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=2025-01-01&endtime=2026-01-01&minmagnitude=5&orderby=time-asc', 'quakes_2025.csv'),
]

if __name__ == "__main__":
    import visualize

    Project.here(__file__, SOURCES).run(visualize.main)
