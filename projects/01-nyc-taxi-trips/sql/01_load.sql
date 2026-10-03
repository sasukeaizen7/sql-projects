-- NYC Yellow Taxi, January 2024: load raw Parquet, clean it, and keep a record of what was rejected.

CREATE OR REPLACE TABLE zones AS
SELECT LocationID AS zone_id, Borough AS borough, Zone AS zone, service_zone
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

CREATE OR REPLACE TABLE trips AS
SELECT
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
WHERE quality = 'ok';
