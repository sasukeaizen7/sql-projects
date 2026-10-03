-- NYC Yellow Taxi, January 2024: load raw Parquet, clean it, and keep a record of what was rejected.

-- Star schema with enforced keys: trips (fact) -> zones (dimension). Drop the child first,
-- because DuckDB refuses to replace a table that a foreign key still points to.
DROP TABLE IF EXISTS trips;
DROP TABLE IF EXISTS zones;

CREATE TABLE zones (
    zone_id      SMALLINT PRIMARY KEY,
    borough      VARCHAR NOT NULL,
    zone         VARCHAR NOT NULL,
    service_zone VARCHAR
);
INSERT INTO zones
SELECT LocationID, Borough, Zone, service_zone
FROM read_csv_auto('data/taxi_zone_lookup.csv');

CREATE OR REPLACE TABLE raw_trips AS
SELECT * FROM read_parquet('data/yellow_tripdata_2024-01.parquet');

-- Every raw row gets exactly one quality verdict (first failing rule wins).
CREATE OR REPLACE TABLE trip_quality AS
SELECT
    *,
    date_diff('second', tpep_pickup_datetime, tpep_dropoff_datetime) / 60.0 AS duration_min,
    CASE
        WHEN tpep_pickup_datetime < TIMESTAMP '2024-01-01'
          OR tpep_pickup_datetime >= TIMESTAMP '2024-02-01'          THEN 'pickup outside January 2024'
        WHEN tpep_dropoff_datetime <= tpep_pickup_datetime           THEN 'dropoff not after pickup'
        WHEN date_diff('minute', tpep_pickup_datetime, tpep_dropoff_datetime) > 180 THEN 'longer than 3 hours'
        WHEN trip_distance <= 0 OR trip_distance > 100               THEN 'distance not in (0, 100] miles'
        WHEN fare_amount <= 0 OR total_amount <= 0                   THEN 'non-positive fare'
        ELSE 'ok'
    END AS quality
FROM raw_trips;

-- The clean fact table. The constraints restate the cleaning rules, so the load fails loudly if a
-- rule above is ever loosened, and every trip must point at a known pickup and dropoff zone.
-- Rows are inserted in pickup order: DuckDB's min/max zone maps then skip whole row groups on
-- time filters, and the Postgres copy keeps the same physical order (see the BRIN benchmark).
CREATE TABLE trips (
    trip_id          BIGINT PRIMARY KEY,
    pickup_at        TIMESTAMP NOT NULL,
    dropoff_at       TIMESTAMP NOT NULL,
    duration_min     DOUBLE NOT NULL,
    passenger_count  BIGINT,
    distance_mi      DOUBLE NOT NULL CHECK (distance_mi > 0 AND distance_mi <= 100),
    pickup_zone_id   SMALLINT NOT NULL REFERENCES zones (zone_id),
    dropoff_zone_id  SMALLINT NOT NULL REFERENCES zones (zone_id),
    payment          VARCHAR NOT NULL CHECK (payment IN ('Credit card', 'Cash', 'No charge', 'Dispute', 'Other')),
    fare_amount      DOUBLE NOT NULL CHECK (fare_amount > 0),
    tip_amount       DOUBLE NOT NULL,
    tolls_amount     DOUBLE NOT NULL,
    total_amount     DOUBLE NOT NULL CHECK (total_amount > 0),
    CHECK (dropoff_at > pickup_at)
);
INSERT INTO trips
SELECT
    row_number() OVER (ORDER BY tpep_pickup_datetime, tpep_dropoff_datetime, PULocationID, DOLocationID, total_amount) AS trip_id,
    tpep_pickup_datetime  AS pickup_at,
    tpep_dropoff_datetime AS dropoff_at,
    duration_min,
    passenger_count,
    trip_distance         AS distance_mi,
    PULocationID          AS pickup_zone_id,
    DOLocationID          AS dropoff_zone_id,
    CASE payment_type WHEN 1 THEN 'Credit card' WHEN 2 THEN 'Cash' WHEN 3 THEN 'No charge'
                      WHEN 4 THEN 'Dispute' ELSE 'Other' END AS payment,
    fare_amount, tip_amount, tolls_amount, total_amount
FROM trip_quality
WHERE quality = 'ok'
ORDER BY trip_id;
