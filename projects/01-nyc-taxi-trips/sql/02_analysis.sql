-- name: data_quality
-- How much of the raw data is usable, and why are rows rejected?
SELECT quality,
       count(*)                                          AS trips,
       round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS pct
FROM trip_quality
GROUP BY quality
ORDER BY trips DESC;

-- name: daily_trips
-- Daily trip volume with a 7-day moving average (window function).
SELECT CAST(pickup_at AS DATE)                                                      AS day,
       count(*)                                                                     AS trips,
       round(avg(count(*)) OVER (ORDER BY CAST(pickup_at AS DATE)
                                 ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 0)     AS trips_7d_avg
FROM trips
GROUP BY day
ORDER BY day;

-- name: demand_heatmap
-- When do New Yorkers take taxis? Average trips per weekday and hour.
WITH per_day_hour AS (
    SELECT CAST(pickup_at AS DATE) AS day, isodow(pickup_at) AS dow, hour(pickup_at) AS hr, count(*) AS trips
    FROM trips
    GROUP BY ALL
)
SELECT dow, hr, round(avg(trips), 1) AS avg_trips
FROM per_day_hour
GROUP BY dow, hr
ORDER BY dow, hr;

-- name: top_pickup_zones
-- Which 10 pickup zones bring in the most fare revenue, and what share of the total?
SELECT z.zone, z.borough,
       count(*)                                                        AS trips,
       round(sum(t.total_amount), 0)                                   AS revenue_usd,
       round(100.0 * sum(t.total_amount) / sum(sum(t.total_amount)) OVER (), 2) AS revenue_share_pct,
       rank() OVER (ORDER BY sum(t.total_amount) DESC)                 AS revenue_rank
FROM trips t
JOIN zones z ON z.zone_id = t.pickup_zone_id
GROUP BY z.zone, z.borough
QUALIFY revenue_rank <= 10
ORDER BY revenue_rank;

-- name: airports_vs_city
-- How do airport trips compare with the rest of the city?
SELECT CASE WHEN z.zone IN ('JFK Airport', 'LaGuardia Airport', 'Newark Airport') THEN z.zone ELSE 'All other zones' END AS pickup,
       count(*)                          AS trips,
       round(avg(t.distance_mi), 1)      AS avg_miles,
       round(avg(t.duration_min), 1)     AS avg_minutes,
       round(avg(t.total_amount), 2)     AS avg_total_usd,
       round(median(t.total_amount), 2)  AS median_total_usd
FROM trips t
JOIN zones z ON z.zone_id = t.pickup_zone_id
GROUP BY pickup
ORDER BY avg_total_usd DESC;

-- name: speed_by_hour
-- Traffic: average speed (mph) of trips by pickup hour, Manhattan only.
SELECT hour(t.pickup_at)                                        AS hr,
       round(avg(t.distance_mi / (t.duration_min / 60.0)), 1)  AS avg_mph,
       count(*)                                                 AS trips
FROM trips t
JOIN zones z ON z.zone_id = t.pickup_zone_id AND z.zone_id = t.pickup_zone_id
JOIN zones d ON d.zone_id = t.dropoff_zone_id
WHERE z.borough = 'Manhattan' AND d.borough = 'Manhattan' AND t.duration_min >= 2
GROUP BY hr
ORDER BY hr;

-- name: tipping
-- Card payments only (cash tips aren't recorded): tip as % of fare by trip length.
SELECT CASE WHEN distance_mi < 1 THEN '1: under 1 mi'
            WHEN distance_mi < 3 THEN '2: 1-3 mi'
            WHEN distance_mi < 10 THEN '3: 3-10 mi'
            ELSE '4: 10+ mi' END                                   AS distance_band,
       count(*)                                                     AS trips,
       round(100.0 * avg(tip_amount / fare_amount), 1)             AS avg_tip_pct,
       round(100.0 * avg(CASE WHEN tip_amount = 0 THEN 1 ELSE 0 END), 1) AS no_tip_pct
FROM trips
WHERE payment = 'Credit card'
GROUP BY distance_band
ORDER BY distance_band;

-- ============================================================================================
-- Advanced SQL
-- ============================================================================================

-- name: revenue_rollup
-- Revenue by pickup borough and payment type, with borough subtotals and a grand total (ROLLUP).
-- grouping() tells a subtotal row apart from a real NULL. Each payment's share is taken against its
-- own borough's subtotal row, which first_value() finds because subtotals sort first in the window.
SELECT CASE WHEN grouping(z.borough) = 1 THEN 'All boroughs' ELSE z.borough END        AS borough,
       CASE WHEN grouping(t.payment) = 1 THEN 'All payments' ELSE t.payment END        AS payment,
       grouping(z.borough, t.payment)                                                   AS level,  -- 0 detail, 1 borough subtotal, 3 grand total
       count(*)                                                                         AS trips,
       round(sum(t.total_amount), 0)                                                    AS revenue_usd,
       round(100.0 * count(*) / first_value(count(*)) OVER (
                 PARTITION BY grouping(z.borough), z.borough ORDER BY grouping(t.payment) DESC), 1) AS share_of_borough_trips_pct
FROM trips t
JOIN zones z ON z.zone_id = t.pickup_zone_id
WHERE z.borough NOT IN ('Unknown', 'N/A', 'EWR')
GROUP BY ROLLUP (z.borough, t.payment)
ORDER BY grouping(z.borough) DESC,
         max(sum(t.total_amount)) OVER (PARTITION BY grouping(z.borough), z.borough) DESC,
         level DESC, trips DESC;

-- name: od_imbalance
-- Which busy zone pairs are the most one-directional? The flow table is self-joined on (A->B, B->A).
WITH flows AS (
    SELECT pickup_zone_id AS a, dropoff_zone_id AS b, count(*) AS trips
    FROM trips
    WHERE pickup_zone_id <> dropoff_zone_id
      AND pickup_zone_id < 264 AND dropoff_zone_id < 264          -- 264/265 = unknown / outside NYC
    GROUP BY ALL
)
SELECT za.zone AS zone_a, zb.zone AS zone_b,
       f.trips              AS a_to_b,
       coalesce(r.trips, 0) AS b_to_a,
       round(f.trips / greatest(coalesce(r.trips, 0), 1), 1) AS ratio
FROM flows f
LEFT JOIN flows r ON r.a = f.b AND r.b = f.a
JOIN zones za ON za.zone_id = f.a
JOIN zones zb ON zb.zone_id = f.b
WHERE f.trips + coalesce(r.trips, 0) >= 3000
ORDER BY ratio DESC
LIMIT 10;

-- name: fare_outliers
-- Overcharging check: Tukey fences on the fare of each pickup -> dropoff route (100+ trips).
-- How often is each payment type far above its route's normal fare (fare > Q3 + 3 x IQR)?
WITH route_stats AS (
    SELECT pickup_zone_id, dropoff_zone_id,
           quantile_cont(fare_amount, 0.25) AS q1,
           quantile_cont(fare_amount, 0.75) AS q3
    FROM trips
    GROUP BY ALL
    HAVING count(*) >= 100
), flagged AS (
    SELECT t.payment, t.fare_amount > s.q3 + 3 * (s.q3 - s.q1) AS outlier
    FROM trips t
    JOIN route_stats s USING (pickup_zone_id, dropoff_zone_id)
)
SELECT payment,
       count(*)                                                     AS trips,
       count(*) FILTER (WHERE outlier)                              AS outliers,
       round(100.0 * count(*) FILTER (WHERE outlier) / count(*), 2) AS outlier_pct
FROM flagged
GROUP BY payment
ORDER BY outlier_pct DESC;

-- name: airport_destinations
-- The top 3 destination zones from each airport: the LATERAL subquery runs once per airport row
-- and can reference it (a.zone_id), which a plain subquery in FROM cannot.
SELECT a.zone AS airport, d.rank, d.destination, d.borough, d.trips,
       round(100.0 * d.trips / a.airport_trips, 1) AS share_pct, d.avg_total_usd
FROM (SELECT z.zone_id, z.zone, count(*) AS airport_trips
      FROM zones z JOIN trips t ON t.pickup_zone_id = z.zone_id
      WHERE z.zone IN ('JFK Airport', 'LaGuardia Airport')
      GROUP BY ALL) a,
LATERAL (
    SELECT row_number() OVER (ORDER BY count(*) DESC) AS rank,
           dz.zone AS destination, dz.borough, count(*) AS trips,
           round(avg(t.total_amount), 2) AS avg_total_usd
    FROM trips t
    JOIN zones dz ON dz.zone_id = t.dropoff_zone_id
    WHERE t.pickup_zone_id = a.zone_id
      AND t.dropoff_zone_id <> a.zone_id AND t.dropoff_zone_id < 264
    GROUP BY dz.zone, dz.borough
    ORDER BY trips DESC
    LIMIT 3
) d
ORDER BY a.zone, d.rank;
