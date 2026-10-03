-- name: event_types
-- What else is in an "earthquake" catalog?
SELECT type, count(*) AS events, round(max(mag), 1) AS max_mag,
       string_agg(DISTINCT CASE WHEN type = 'nuclear explosion' THEN strftime(timezone('UTC', time), '%Y-%m-%d') || ' ' || place END, ' | '
                  ORDER BY CASE WHEN type = 'nuclear explosion' THEN strftime(timezone('UTC', time), '%Y-%m-%d') || ' ' || place END) AS details
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
ORDER BY m6_plus DESC, region
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

-- ============================================================================================
-- Advanced SQL
-- ============================================================================================

-- name: aftershock_sequences
-- Aftershocks of the largest earthquakes: M5+ events within 300 km and 30 days after each M7.8+
-- mainshock. A range self-join (time window + latitude band), then the exact great-circle distance.
-- A mainshock must not itself follow an equal or larger quake nearby (Tohoku's M7.9 aftershock would
-- otherwise count as a second sequence). A 300 km radius undercounts very long ruptures (Sumatra 2004
-- broke 1,300 km of fault).
WITH main AS (
    SELECT * FROM quakes m
    WHERE mag >= 7.8
      AND NOT EXISTS (SELECT 1 FROM quakes b
                      WHERE b.mag >= m.mag AND b.id <> m.id
                        AND b.occurred_at_utc BETWEEN m.occurred_at_utc - INTERVAL 30 DAY AND m.occurred_at_utc
                        AND haversine_km(m.latitude, m.longitude, b.latitude, b.longitude) <= 300)
)
SELECT strftime(m.occurred_at_utc, '%Y-%m-%d')                            AS date_utc,
       m.mag, m.region,
       count(a.id)                                                         AS aftershocks_30d,
       count(a.id) FILTER (WHERE a.occurred_at_utc < m.occurred_at_utc + INTERVAL 1 DAY) AS first_day,
       count(a.id) FILTER (WHERE a.mag >= 6)                               AS m6_plus,
       round(max(a.mag), 1)                                                AS largest_aftershock
FROM main m
LEFT JOIN quakes a
       ON a.occurred_at_utc >  m.occurred_at_utc
      AND a.occurred_at_utc <= m.occurred_at_utc + INTERVAL 30 DAY
      AND abs(a.latitude - m.latitude) < 3                                  -- cheap pre-filter, ~330 km
      AND haversine_km(m.latitude, m.longitude, a.latitude, a.longitude) <= 300
GROUP BY m.id, m.occurred_at_utc, m.mag, m.region
ORDER BY aftershocks_30d DESC
LIMIT 12;

-- name: foreshocks
-- ASOF JOIN: for each M7+ earthquake, the most recent earlier M5+ event in the same region.
-- How often does a big one follow another quake within a day, a week, a month?
WITH big AS (SELECT * FROM quakes WHERE mag >= 7),
prior AS (
    SELECT b.id, b.mag, b.occurred_at_utc,
           date_diff('second', p.occurred_at_utc, b.occurred_at_utc) / 86400.0 AS days_since_previous
    FROM big b
    ASOF LEFT JOIN quakes p
           ON p.region = b.region AND p.occurred_at_utc < b.occurred_at_utc
)
SELECT count(*)                                                                    AS m7_quakes,
       count(*) FILTER (WHERE days_since_previous <= 1)                           AS within_1_day,
       count(*) FILTER (WHERE days_since_previous <= 7)                           AS within_7_days,
       count(*) FILTER (WHERE days_since_previous <= 30)                          AS within_30_days,
       round(100.0 * count(*) FILTER (WHERE days_since_previous <= 7) / count(*), 1) AS pct_within_7_days,
       round(median(days_since_previous), 1)                                      AS median_days_since_previous
FROM prior;

-- name: busiest_12_months
-- Sliding 365-day window (RANGE frame with an INTERVAL): the busiest and the quietest 12 months for M6+.
-- Windows end at each M6+ event. The "full windows only" filter must run after the window function:
-- a WHERE in the same SELECT would remove the earlier rows before they are counted.
WITH m6 AS (SELECT occurred_at_utc FROM quakes WHERE mag >= 6),
all_windows AS (
    SELECT occurred_at_utc AS window_end,
           count(*) OVER (ORDER BY occurred_at_utc
                          RANGE BETWEEN INTERVAL 365 DAY PRECEDING AND CURRENT ROW) AS m6_in_window
    FROM m6
),
win AS (SELECT * FROM all_windows WHERE window_end >= TIMESTAMP '2001-01-01')   -- full windows only
(SELECT 'busiest' AS which, window_end::DATE - 365 AS window_start, window_end::DATE AS window_end, m6_in_window
 FROM win ORDER BY m6_in_window DESC, window_end LIMIT 1)
UNION ALL
(SELECT 'quietest', window_end::DATE - 365, window_end::DATE, m6_in_window
 FROM win ORDER BY m6_in_window, window_end LIMIT 1);

-- name: m7_month_streaks
-- Gaps and islands on a full monthly calendar (generated with range(), so empty months exist):
-- the longest run of consecutive months with at least one M7+, and the longest run without one.
WITH months AS (
    SELECT range AS month FROM range(DATE '2000-01-01', DATE '2026-01-01', INTERVAL 1 MONTH)
), flagged AS (
    SELECT m.month, count(q.id) > 0 AS has_m7
    FROM months m
    LEFT JOIN quakes q ON date_trunc('month', q.occurred_at_utc) = m.month AND q.mag >= 7
    GROUP BY m.month
), islands AS (
    SELECT *, row_number() OVER (ORDER BY month)
              - row_number() OVER (PARTITION BY has_m7 ORDER BY month) AS island
    FROM flagged
)
SELECT CASE WHEN has_m7 THEN 'months with an M7+' ELSE 'months without' END AS streak,
       count(*) AS months, min(month) AS first_month, max(month) AS last_month
FROM islands
GROUP BY has_m7, island
QUALIFY row_number() OVER (PARTITION BY has_m7 ORDER BY count(*) DESC, min(month)) = 1
ORDER BY streak;
