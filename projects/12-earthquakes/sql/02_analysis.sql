-- name: event_types
-- What else is in an "earthquake" catalog?
SELECT type, count(*) AS events, round(max(mag), 1) AS max_mag,
       string_agg(DISTINCT CASE WHEN type = 'nuclear explosion' THEN strftime(timezone('UTC', time), '%Y-%m-%d') || ' ' || place END, ' | ') AS details
FROM events_raw
GROUP BY type
ORDER BY events DESC;

-- name: per_year
-- Yearly counts by magnitude class: is the planet getting more active?
SELECT year,
       count(*)                                  AS m5_plus,
       count(*) FILTER (WHERE mag >= 6)          AS m6_plus,
       count(*) FILTER (WHERE mag >= 7)          AS m7_plus,
       count(*) FILTER (WHERE mag >= 8)          AS m8_plus
FROM quakes
GROUP BY year
ORDER BY year;

-- name: gutenberg_richter
-- Frequency-magnitude law: cumulative count of quakes >= M, per 0.1 magnitude step.
WITH bins AS (
    SELECT round(mag, 1) AS m, count(*) AS n FROM quakes GROUP BY m
)
SELECT m AS magnitude, n AS events_in_bin,
       sum(n) OVER (ORDER BY m DESC ROWS UNBOUNDED PRECEDING) AS events_at_or_above,
       round(log10(sum(n) OVER (ORDER BY m DESC ROWS UNBOUNDED PRECEDING)), 4) AS log10_n
FROM bins
ORDER BY m;

-- name: b_value
-- Fit log10(N >= M) = a - b*M on the complete range (M 5.0-8.0). b ~ 1 is the textbook value.
WITH bins AS (SELECT round(mag, 1) AS m, count(*) AS n FROM quakes GROUP BY m),
cum AS (SELECT m, sum(n) OVER (ORDER BY m DESC ROWS UNBOUNDED PRECEDING) AS n_ge FROM bins)
SELECT round(-regr_slope(log10(n_ge), m), 3)     AS b_value,
       round(regr_intercept(log10(n_ge), m), 3)  AS a_value,
       round(regr_r2(log10(n_ge), m), 4)         AS r2
FROM cum
WHERE m BETWEEN 5.0 AND 8.0;

-- name: largest
-- The 10 largest earthquakes since 2000.
SELECT strftime(occurred_at_utc, '%Y-%m-%d') AS date_utc, mag, round(depth_km, 0) AS depth_km, place
FROM quakes
ORDER BY mag DESC, occurred_at_utc
LIMIT 10;

-- name: regions
-- Where do M6+ quakes happen? Top regions.
SELECT region, count(*) AS m6_plus, round(max(mag), 1) AS max_mag
FROM quakes
WHERE mag >= 6
GROUP BY region
ORDER BY m6_plus DESC
LIMIT 12;

-- name: depth
-- Shallow, intermediate and deep earthquakes.
SELECT depth_class, count(*) AS events,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct,
       round(avg(mag), 2) AS avg_mag,
       count(*) FILTER (WHERE mag >= 7) AS m7_plus
FROM quakes
GROUP BY depth_class
ORDER BY depth_class;

-- name: waiting_time
-- Days between consecutive M7+ earthquakes (LAG): how regular are the big ones?
WITH big AS (
    SELECT occurred_at_utc, date_diff('day', lag(occurred_at_utc) OVER (ORDER BY occurred_at_utc), occurred_at_utc) AS gap_days
    FROM quakes WHERE mag >= 7
)
SELECT count(*) AS m7_events, round(avg(gap_days), 1) AS mean_gap_days, median(gap_days) AS median_gap_days,
       max(gap_days) AS longest_gap_days, count(*) FILTER (WHERE gap_days = 0) AS same_day_pairs
FROM big;

-- name: map_points
-- Every M6+ quake for the map.
SELECT latitude, longitude, depth_km, mag
FROM quakes
WHERE mag >= 6
ORDER BY mag;
