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
