-- City of Chicago, Crimes 2001-present (filtered to 2024 at download), plus community area names.

-- DuckDB has no initcap(): a small macro turns "MOTOR VEHICLE THEFT" into "Motor Vehicle Theft".
CREATE OR REPLACE MACRO initcap(s) AS
    list_aggregate(list_transform(string_split(lower(s), ' '), w -> upper(w[1]) || w[2:]), 'string_agg', ' ');

CREATE OR REPLACE TABLE community_areas AS
SELECT CAST(area_numbe AS INTEGER) AS community_area, initcap(community) AS community
FROM read_csv('data/community_areas.csv', header = true);

CREATE OR REPLACE TABLE crimes AS
SELECT
    id,
    date                                   AS occurred_at,
    month(date)                            AS month,
    isodow(date)                           AS dow,
    hour(date)                             AS hr,
    initcap(primary_type)                  AS crime_type,
    description,
    initcap(location_description)          AS location,
    arrest,
    domestic,
    CAST(district AS INTEGER)              AS district,
    CAST(community_area AS INTEGER)        AS community_area
FROM read_csv('data/crimes_2024.csv', header = true, types = {'arrest': 'BOOLEAN', 'domestic': 'BOOLEAN'});
