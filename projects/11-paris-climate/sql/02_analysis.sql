-- name: coverage
-- Completeness check: days per year and missing values.
SELECT min(day) AS first_day, max(day) AS last_day, count(*) AS days,
       count(*) FILTER (WHERE t_mean IS NULL) AS missing_temperature,
       count(*) FILTER (WHERE rain_mm IS NULL) AS missing_rain,
       count(DISTINCT year) FILTER (WHERE true) AS years
FROM daily;

-- name: yearly
-- Yearly mean temperature, anomaly vs 1951-1980, and 10-year rolling mean.
WITH y AS (
    SELECT year, avg(t_mean) AS t_mean, sum(rain_mm) AS rain_mm,
           count(*) FILTER (WHERE t_max >= 30) AS hot_days,
           count(*) FILTER (WHERE t_min >= 20) AS tropical_nights,
           count(*) FILTER (WHERE t_min < 0)   AS frost_days
    FROM daily
    GROUP BY year
)
SELECT year,
       round(t_mean, 2)                                                                    AS t_mean,
       round(t_mean - (SELECT avg(t_mean) FROM daily WHERE year BETWEEN 1951 AND 1980), 2) AS anomaly,
       round(avg(t_mean) OVER (ORDER BY year ROWS BETWEEN 9 PRECEDING AND CURRENT ROW), 2) AS t_mean_10y,
       round(rain_mm, 0) AS rain_mm, hot_days, tropical_nights, frost_days
FROM y
ORDER BY year;

-- name: trend
-- Warming rate: least-squares slope of yearly mean temperature, per decade.
WITH y AS (SELECT year, avg(t_mean) AS t FROM daily GROUP BY year)
SELECT round(10 * regr_slope(t, year), 2)                                   AS warming_per_decade_all,
       round(10 * regr_slope(t, year) FILTER (WHERE year >= 1980), 2)       AS warming_per_decade_since_1980,
       round(regr_r2(t, year), 2)                                           AS r2_all
FROM y;

-- name: decades
-- Decade averages: mean temperature, hot days, frost days, tropical nights.
SELECT (year // 10) * 10                                AS decade,
       round(avg(t_mean), 2)                            AS t_mean,
       round(count(*) FILTER (WHERE t_max >= 30) / count(DISTINCT year)::DOUBLE, 1) AS hot_days_per_year,
       round(count(*) FILTER (WHERE t_min < 0) / count(DISTINCT year)::DOUBLE, 1)   AS frost_days_per_year,
       round(count(*) FILTER (WHERE t_min >= 20) / count(DISTINCT year)::DOUBLE, 1) AS tropical_nights_per_year
FROM daily
GROUP BY decade
ORDER BY decade;

-- name: monthly_warming
-- Which months warmed most? 1996-2025 vs the 1951-1980 baseline.
SELECT d.month,
       round(b.t_mean_1951_1980, 1)                 AS baseline_c,
       round(avg(d.t_mean), 1)                      AS recent_c,
       round(avg(d.t_mean) - b.t_mean_1951_1980, 2) AS warming_c
FROM daily d
JOIN baseline b USING (month)
WHERE d.year BETWEEN 1996 AND 2025
GROUP BY d.month, b.t_mean_1951_1980
ORDER BY d.month;

-- name: hottest_days
-- The 10 hottest days on record (daily maximum).
SELECT day, t_max, t_min, rank() OVER (ORDER BY t_max DESC) AS rnk
FROM daily
QUALIFY rnk <= 10
ORDER BY rnk, day;

-- name: warmest_years
SELECT year, round(avg(t_mean), 2) AS t_mean, rank() OVER (ORDER BY avg(t_mean) DESC) AS rnk
FROM daily
GROUP BY year
QUALIFY rnk <= 10
ORDER BY rnk;
