-- USGS earthquake catalog: every magnitude 5+ event worldwide, 2000-2025 (one file per year).

CREATE OR REPLACE TABLE events_raw AS
SELECT * FROM read_csv('data/quakes_*.csv', header = true, union_by_name = true);

-- The catalog also lists nuclear tests, volcanic eruptions and landslides: keep earthquakes only.
CREATE OR REPLACE TABLE quakes AS
SELECT
    id,
    timezone('UTC', time)                                                     AS occurred_at_utc,
    year(timezone('UTC', time))                                              AS year,
    latitude, longitude,
    depth                                                                    AS depth_km,
    mag,
    magType                                                                  AS mag_type,
    place,
    -- "45 km SW of Tokyo, Japan" -> "Japan"; named events like "2010 Maule, Chile Earthquake" -> "Chile".
    trim(regexp_replace(CASE WHEN place LIKE '%,%' THEN split_part(place, ',', -1) ELSE place END,
                        '^\d{4} | Earthquake$', '', 'g'))                           AS region,
    CASE WHEN depth < 70 THEN '1. shallow (< 70 km)'
         WHEN depth < 300 THEN '2. intermediate (70-300 km)'
         ELSE '3. deep (300+ km)' END                                        AS depth_class
FROM events_raw
WHERE type = 'earthquake';
