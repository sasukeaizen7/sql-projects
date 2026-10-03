-- USGS earthquake catalog: every magnitude 5+ event worldwide, 2000-2025 (one file per year).

CREATE OR REPLACE TABLE events_raw AS
SELECT * FROM read_csv('data/quakes_*.csv', header = true, union_by_name = true);

-- The catalog also lists nuclear tests, volcanic eruptions and landslides: keep earthquakes only.
-- The constraints document what a valid event is: unique id, magnitude 5+ (the API filter), real
-- coordinates, and depth from slightly above sea level (-5 km) down to the deepest known quakes.
CREATE OR REPLACE TABLE quakes (
    id              VARCHAR PRIMARY KEY,
    occurred_at_utc TIMESTAMP NOT NULL,
    year            INTEGER NOT NULL,
    latitude        DOUBLE NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude       DOUBLE NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    depth_km        DOUBLE NOT NULL CHECK (depth_km BETWEEN -5 AND 800),
    mag             DOUBLE NOT NULL CHECK (mag BETWEEN 5 AND 10),
    mag_type        VARCHAR,
    place           VARCHAR,
    region          VARCHAR,
    depth_class     VARCHAR NOT NULL
);
INSERT INTO quakes
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

-- Great-circle distance in km (haversine), used by the aftershock queries.
CREATE OR REPLACE MACRO haversine_km(lat1, lon1, lat2, lon2) AS
    2 * 6371 * asin(sqrt(
        pow(sin(radians(lat2 - lat1) / 2), 2) +
        cos(radians(lat1)) * cos(radians(lat2)) * pow(sin(radians(lon2 - lon1) / 2), 2)));
