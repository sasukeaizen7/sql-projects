-- Index benchmarks on 2.87M trips in PostgreSQL (run by toolkit/postgres.py).
-- Each query is timed with the primary keys only, then after creating the index(es) listed in its
-- "-- index:" lines; the result must not change. Indexes are dropped between queries.

-- name: zone_time_window
-- Every trip from Times Square between 17:00 and 19:00 on Friday 12 January, in pickup order.
-- Composite B-tree: equality column first, range column second, so the matching rows are one
-- contiguous slice of the index, already sorted (no Sort node).
-- index: CREATE INDEX trips_zone_time ON trips (pickup_zone_id, pickup_at)
SELECT trip_id, pickup_at, dropoff_zone_id, total_amount
FROM trips
WHERE pickup_zone_id = 230
  AND pickup_at >= '2024-01-12 17:00' AND pickup_at < '2024-01-12 19:00'
ORDER BY pickup_at, trip_id;

-- name: one_day_btree
-- Revenue per hour on 15 January, with a regular B-tree on pickup_at.
-- index: CREATE INDEX trips_pickup_btree ON trips (pickup_at)
SELECT date_trunc('hour', pickup_at) AS hour, count(*) AS trips, sum(total_amount) AS revenue
FROM trips
WHERE pickup_at >= '2024-01-15' AND pickup_at < '2024-01-16'
GROUP BY 1
ORDER BY 1;

-- name: one_day_brin
-- The same query with a BRIN index: it stores only the min/max pickup_at of each block range, so it
-- is over 2,000 times smaller than the B-tree. It works because the rows are stored in time order.
-- index: CREATE INDEX trips_pickup_brin ON trips USING brin (pickup_at)
SELECT date_trunc('hour', pickup_at) AS hour, count(*) AS trips, sum(total_amount) AS revenue
FROM trips
WHERE pickup_at >= '2024-01-15' AND pickup_at < '2024-01-16'
GROUP BY 1
ORDER BY 1;

-- name: non_sargable
-- Pitfall: the same day written as a cast on the column. The B-tree on pickup_at exists but cannot be
-- used, because the predicate is on pickup_at::date, not on pickup_at: Postgres falls back to a full scan.
-- index: CREATE INDEX trips_pickup_btree ON trips (pickup_at)
SELECT count(*) AS trips, sum(total_amount) AS revenue
FROM trips
WHERE pickup_at::date = '2024-01-15';

-- name: expression_index
-- Fix 1 (fix 2 is to rewrite the filter as a range, as in one_day_btree): index the expression itself.
-- index: CREATE INDEX trips_pickup_day ON trips ((pickup_at::date))
SELECT count(*) AS trips, sum(total_amount) AS revenue
FROM trips
WHERE pickup_at::date = '2024-01-15';

-- name: partial_index
-- Disputed trips above $100. A partial index only stores the 0.8% of rows that are disputes,
-- so it is far smaller than an index on the whole table and cheaper to maintain on insert.
-- index: CREATE INDEX trips_dispute_amount ON trips (total_amount) WHERE payment = 'Dispute'
SELECT trip_id, pickup_at, pickup_zone_id, total_amount
FROM trips
WHERE payment = 'Dispute' AND total_amount > 100
ORDER BY total_amount DESC, trip_id;

-- name: jfk_daily_plain
-- Daily trips and revenue from JFK with a plain index on pickup_zone_id: the index finds the 138k
-- rows, but every one of them must still be fetched from the table (Bitmap Heap Scan).
-- index: CREATE INDEX trips_pickup_zone ON trips (pickup_zone_id)
SELECT pickup_at::date AS day, count(*) AS trips, sum(total_amount) AS revenue
FROM trips
WHERE pickup_zone_id = 132
GROUP BY 1
ORDER BY 1;

-- name: jfk_daily_covering
-- Same query with a covering index: INCLUDE stores the other two columns in the index leaves, so
-- Postgres answers from the index alone (Index Only Scan) and never touches the table.
-- index: CREATE INDEX trips_pickup_zone_cover ON trips (pickup_zone_id) INCLUDE (pickup_at, total_amount)
SELECT pickup_at::date AS day, count(*) AS trips, sum(total_amount) AS revenue
FROM trips
WHERE pickup_zone_id = 132
GROUP BY 1
ORDER BY 1;

-- name: top_n
-- The 10 most expensive trips. Without an index Postgres reads and sorts (top-N heapsort) all 2.87M
-- rows; with one it reads the first 10 entries of the index and stops.
-- index: CREATE INDEX trips_total_desc ON trips (total_amount DESC)
SELECT trip_id, pickup_at, pickup_zone_id, dropoff_zone_id, total_amount
FROM trips
ORDER BY total_amount DESC, trip_id
LIMIT 10;

-- name: fk_join
-- Trips picked up in Glen Oaks, Queens, found by zone name through the join (40 trips).
-- Postgres does not index foreign keys, so without this index the join scans all 2.87M trips.
-- index: CREATE INDEX trips_pickup_zone ON trips (pickup_zone_id)
SELECT z.zone, t.trip_id, t.pickup_at, t.total_amount
FROM zones z
JOIN trips t ON t.pickup_zone_id = z.zone_id
WHERE z.zone = 'Glen Oaks'
ORDER BY t.pickup_at, t.trip_id;

-- name: low_selectivity
-- Counter-example: credit-card trips are 80% of the table. An index on payment is useless here, and
-- the planner rightly keeps the sequential scan: indexes pay off for selective filters only.
-- index: CREATE INDEX trips_payment ON trips (payment)
SELECT count(*) AS trips, avg(tip_amount / fare_amount) AS avg_tip_ratio
FROM trips
WHERE payment = 'Credit card';
