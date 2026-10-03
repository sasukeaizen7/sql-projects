-- The clean NYC taxi tables in PostgreSQL, filled from DuckDB by toolkit/postgres.py.
-- Only constraint indexes exist here (the primary keys); every other index is created and
-- measured by sql/04_index_benchmarks.sql. Money is NUMERIC so sums are exact, whatever the plan.

CREATE TABLE zones (
    zone_id      smallint PRIMARY KEY,
    borough      text NOT NULL,
    zone         text NOT NULL,
    service_zone text
);

CREATE TABLE trips (
    trip_id          bigint PRIMARY KEY,
    pickup_at        timestamp NOT NULL,
    dropoff_at       timestamp NOT NULL,
    passenger_count  smallint,
    distance_mi      numeric(6, 2) NOT NULL CHECK (distance_mi > 0 AND distance_mi <= 100),
    -- Postgres does NOT index foreign keys automatically (see the fk_join benchmark).
    pickup_zone_id   smallint NOT NULL REFERENCES zones,
    dropoff_zone_id  smallint NOT NULL REFERENCES zones,
    payment          text NOT NULL CHECK (payment IN ('Credit card', 'Cash', 'No charge', 'Dispute', 'Other')),
    fare_amount      numeric(8, 2) NOT NULL CHECK (fare_amount > 0),
    tip_amount       numeric(8, 2) NOT NULL,
    tolls_amount     numeric(8, 2) NOT NULL,
    total_amount     numeric(8, 2) NOT NULL CHECK (total_amount > 0),
    CHECK (dropoff_at > pickup_at)
);

-- Store trips in pickup order, as a real append-only feed would be: that physical order is what
-- makes a tiny BRIN index usable on pickup_at.
-- source: trips = SELECT trip_id, pickup_at, dropoff_at, passenger_count, distance_mi, pickup_zone_id, dropoff_zone_id, payment, fare_amount, tip_amount, tolls_amount, total_amount FROM trips ORDER BY trip_id
