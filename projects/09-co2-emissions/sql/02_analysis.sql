-- name: grain_check
-- Why aggregates must be excluded: summing every row of 2024 vs the World row.
SELECT
    (SELECT round(sum(co2), 0) FROM owid_raw WHERE year = 2024)                     AS sum_all_rows_mt,
    (SELECT round(sum(co2), 0) FROM country_year WHERE year = 2024)                 AS sum_countries_mt,
    (SELECT round(co2, 0) FROM world_year WHERE year = 2024)                        AS world_row_mt,
    (SELECT count(DISTINCT country) FROM country_year)                              AS countries,
    (SELECT count(DISTINCT country) FROM owid_raw) - (SELECT count(DISTINCT country) FROM country_year) AS aggregate_rows;

-- name: top_emitters_2024
-- The 10 largest emitters in 2024: total, share of world, per person.
SELECT country,
       round(co2, 0)                                                AS co2_mt,
       round(100.0 * co2 / (SELECT co2 FROM world_year WHERE year = 2024), 1) AS world_share_pct,
       round(co2_per_capita, 1)                                     AS t_per_person,
       round(population / 1e6, 0)                                   AS population_m
FROM country_year
WHERE year = 2024
ORDER BY co2 DESC
LIMIT 10;

-- name: cumulative
-- Historical responsibility: cumulative emissions 1750-2024 and share of the world total.
SELECT country,
       round(cumulative_co2 / 1000, 0)                                                AS cumulative_gt,
       round(100.0 * cumulative_co2 / sum(cumulative_co2) OVER (), 1)               AS share_of_countries_pct
FROM country_year
WHERE year = 2024
QUALIFY row_number() OVER (ORDER BY cumulative_co2 DESC) <= 10
ORDER BY cumulative_co2 DESC;

-- name: change_since_2005
-- Who cut, who grew? CO2 change 2005 -> 2024 for the 15 largest emitters of 2024.
WITH big AS (
    SELECT country FROM country_year WHERE year = 2024 ORDER BY co2 DESC LIMIT 15
)
SELECT c.country,
       round(max(c.co2) FILTER (WHERE c.year = 2005), 0)                                         AS co2_2005,
       round(max(c.co2) FILTER (WHERE c.year = 2024), 0)                                         AS co2_2024,
       round(100.0 * (max(c.co2) FILTER (WHERE c.year = 2024) / max(c.co2) FILTER (WHERE c.year = 2005) - 1), 1) AS change_pct
FROM country_year c
JOIN big USING (country)
GROUP BY c.country
ORDER BY change_pct;

-- name: world_by_fuel
-- Where world emissions come from, every 5 years since 1900.
SELECT year,
       round(coal_co2 / 1000, 2)   AS coal_gt,
       round(oil_co2 / 1000, 2)    AS oil_gt,
       round(gas_co2 / 1000, 2)    AS gas_gt,
       round(cement_co2 / 1000, 2) AS cement_gt,
       round(co2 / 1000, 2)        AS total_gt
FROM world_year
WHERE year >= 1900 AND (year % 5 = 0 OR year = 2024)
ORDER BY year;

-- name: per_capita_leaders
-- Highest emissions per person among countries of 10M+ people (2024).
SELECT country, round(co2_per_capita, 1) AS t_per_person, round(population / 1e6, 0) AS population_m
FROM country_year
WHERE year = 2024 AND population >= 10e6
ORDER BY co2_per_capita DESC
LIMIT 10;

-- name: offshored
-- Consumption-based vs territorial emissions (latest year available per country):
-- positive trade_co2 = the country imports more CO2 embedded in goods than it exports.
SELECT country, year,
       round(co2, 0)                                    AS territorial_mt,
       round(consumption_co2, 0)                        AS consumption_mt,
       round(100.0 * trade_co2 / co2, 1)                AS imported_pct_of_territorial
FROM country_year
WHERE consumption_co2 IS NOT NULL AND country IN ('United Kingdom', 'France', 'Germany', 'United States', 'Japan', 'China', 'India', 'Russia')
QUALIFY year = max(year) OVER (PARTITION BY country)
ORDER BY imported_pct_of_territorial DESC;
