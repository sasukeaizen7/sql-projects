-- name: overview
SELECT count(*)                                              AS crimes,
       round(100.0 * avg(arrest::INT), 1)                    AS arrest_pct,
       round(100.0 * avg(domestic::INT), 1)                  AS domestic_pct,
       count(*) FILTER (WHERE community_area IS NULL)        AS no_community_area,
       count(DISTINCT crime_type)                            AS crime_types
FROM crimes;

-- name: by_type
-- The 12 most frequent crime types and how often they lead to an arrest.
SELECT crime_type,
       count(*)                                                AS crimes,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1)      AS share_pct,
       round(100.0 * avg(arrest::INT), 1)                      AS arrest_pct,
       round(100.0 * avg(domestic::INT), 1)                    AS domestic_pct
FROM crimes
GROUP BY crime_type
ORDER BY crimes DESC
LIMIT 12;

-- name: weekly_rhythm
-- When does crime happen? Average crimes per weekday x hour.
-- A third of timestamps are rounded to the hour, and 00:00 / 12:00 double as "time unknown"
-- (see midnight_spike), as does 00:01, so only minute-precise timestamps are used here.
WITH days AS (
    SELECT isodow(d) AS dow, count(*) AS n_days
    FROM range(DATE '2024-01-01', DATE '2025-01-01', INTERVAL 1 DAY) t(d)
    GROUP BY dow
)
SELECT c.dow, c.hr, round(count(*) / any_value(d.n_days)::DOUBLE, 2) AS avg_crimes
FROM crimes c
JOIN days d USING (dow)
WHERE minute(c.occurred_at) <> 0                                       -- rounded to the hour
  AND strftime(c.occurred_at, '%H:%M') <> '00:01'                    -- another "unknown time" placeholder
GROUP BY c.dow, c.hr
ORDER BY c.dow, c.hr;

-- name: midnight_spike
-- A data artefact: crimes with an unknown time are often recorded at 00:00 or 12:00 exactly.
SELECT strftime(occurred_at, '%H:%M') AS clock_time, count(*) AS crimes
FROM crimes
GROUP BY clock_time
ORDER BY crimes DESC
LIMIT 5;

-- name: monthly
SELECT month, count(*) AS crimes,
       round(100.0 * (count(*) / avg(count(*)) OVER () - 1), 1) AS vs_monthly_avg_pct
FROM crimes
GROUP BY month
ORDER BY month;

-- name: community_areas
-- Community areas with the most crimes, and their share of the city total.
SELECT a.community, count(*) AS crimes,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS share_pct,
       round(100.0 * avg(c.arrest::INT), 1) AS arrest_pct,
       rank() OVER (ORDER BY count(*) DESC) AS rnk
FROM crimes c
JOIN community_areas a USING (community_area)
GROUP BY a.community
QUALIFY rnk <= 10
ORDER BY rnk;

-- name: concentration
-- How concentrated is violent crime? Share of homicides in the 10 worst of the 77 community areas.
WITH h AS (
    SELECT community_area, count(*) AS n FROM crimes WHERE crime_type = 'Homicide' GROUP BY community_area
), r AS (
    SELECT *, row_number() OVER (ORDER BY n DESC) AS rn FROM h
)
SELECT (SELECT count(*) FROM crimes WHERE crime_type = 'Homicide')               AS homicides,
       sum(n) FILTER (WHERE rn <= 10)                                             AS in_top10_areas,
       round(100.0 * sum(n) FILTER (WHERE rn <= 10) / sum(n), 1)                  AS top10_share_pct
FROM r;

-- name: locations
SELECT location, count(*) AS crimes, round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS share_pct
FROM crimes
GROUP BY location
ORDER BY crimes DESC
LIMIT 8;
