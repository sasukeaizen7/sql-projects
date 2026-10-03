-- name: yearly
-- Total entries per year and network, with year-over-year change (LAG).
SELECT year, network,
       count(*)                                                                    AS stations,
       sum(entries)                                                                AS entries,
       round(100.0 * (sum(entries) / lag(sum(entries)) OVER (PARTITION BY network ORDER BY year) - 1), 1) AS yoy_pct
FROM traffic
GROUP BY year, network
ORDER BY network, year;

-- name: top_stations
-- The 10 busiest stations in 2019 (pre-COVID) and how far they had recovered by 2021.
WITH pivoted AS (
    SELECT station, network,
           sum(entries) FILTER (WHERE year = 2019) AS entries_2019,
           sum(entries) FILTER (WHERE year = 2020) AS entries_2020,
           sum(entries) FILTER (WHERE year = 2021) AS entries_2021
    FROM traffic
    GROUP BY station, network
)
SELECT station, network, entries_2019, entries_2020, entries_2021,
       round(100.0 * entries_2021 / entries_2019, 1)               AS recovery_2021_pct,
       rank() OVER (ORDER BY entries_2019 DESC)                    AS rank_2019
FROM pivoted
QUALIFY rank_2019 <= 10
ORDER BY rank_2019;

-- name: recovery_by_area
-- 2021 traffic as % of 2019, like-for-like: only stations open in both years
-- (the Line 14 extension opened Pont Cardinet and Clichy-Saint-Ouen in Dec 2020).
WITH per_station AS (
    SELECT station, any_value(city) AS city, any_value(arrondissement) AS arrondissement,
           sum(entries) FILTER (WHERE year = 2019) AS e2019,
           sum(entries) FILTER (WHERE year = 2021) AS e2021
    FROM traffic
    WHERE network = 'Métro'
    GROUP BY station
    HAVING e2019 > 0 AND e2021 > 0
)
SELECT CASE WHEN city = 'Paris' THEN coalesce(CAST(arrondissement AS VARCHAR), '?') ELSE 'Suburbs' END AS area,
       count(*)                                    AS stations,
       sum(e2019)                                  AS entries_2019,
       sum(e2021)                                  AS entries_2021,
       round(100.0 * sum(e2021) / sum(e2019), 1)   AS recovery_pct
FROM per_station
GROUP BY area
ORDER BY recovery_pct;

-- name: rank_movers
-- Metro stations that climbed or fell most in the ranking between 2013 and 2019 (DENSE_RANK per year).
WITH ranked AS (
    SELECT year, station, entries, dense_rank() OVER (PARTITION BY year ORDER BY entries DESC) AS rnk
    FROM traffic
    WHERE network = 'Métro' AND year IN (2013, 2019)
), compared AS (
    SELECT station,
           max(rnk) FILTER (WHERE year = 2013) AS rank_2013,
           max(rnk) FILTER (WHERE year = 2019) AS rank_2019,
           max(entries) FILTER (WHERE year = 2013) AS entries_2013,
           max(entries) FILTER (WHERE year = 2019) AS entries_2019
    FROM ranked
    GROUP BY station
)
SELECT station, rank_2013, rank_2019, rank_2013 - rank_2019 AS places_gained,
       round(100.0 * (entries_2019::DOUBLE / entries_2013 - 1), 1) AS growth_pct
FROM compared
WHERE rank_2013 IS NOT NULL AND rank_2019 IS NOT NULL
ORDER BY abs(rank_2013 - rank_2019) DESC
LIMIT 10;

-- name: concentration
-- How concentrated is Metro traffic? Share carried by the top 10% of stations, per year.
WITH r AS (
    SELECT year, entries, percent_rank() OVER (PARTITION BY year ORDER BY entries DESC) AS pr
    FROM traffic
    WHERE network = 'Métro'
)
SELECT year,
       round(100.0 * sum(entries) FILTER (WHERE pr < 0.10) / sum(entries), 1) AS top10pct_share
FROM r
GROUP BY year
ORDER BY year;

-- name: hubs
-- Do interchange stations (more lines) attract more entries? (2019, Metro)
SELECT lines_served, count(*) AS stations, round(median(entries) / 1e6, 2) AS median_entries_m
FROM traffic
WHERE year = 2019 AND network = 'Métro'
GROUP BY lines_served
ORDER BY lines_served;
