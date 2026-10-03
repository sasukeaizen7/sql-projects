-- The clean OpenFlights graph in PostgreSQL, filled from DuckDB by toolkit/postgres.py.
-- Only constraint indexes exist here (primary and unique keys); every other index is created and
-- measured by sql/04_index_benchmarks.sql.

-- cube + earthdistance (contrib extensions shipped with PostgreSQL) give ll_to_earth(lat, lon) and
-- a GiST-indexable distance, used by the nearest-airport benchmarks.
CREATE EXTENSION IF NOT EXISTS cube SCHEMA public;
CREATE EXTENSION IF NOT EXISTS earthdistance SCHEMA public;

CREATE TABLE airports (
    airport_id integer PRIMARY KEY,
    name       text,
    city       text,
    country    text,
    iata       text UNIQUE,
    icao       text,
    lat        double precision NOT NULL CHECK (lat BETWEEN -90 AND 90),
    lon        double precision NOT NULL CHECK (lon BETWEEN -180 AND 180)
);

CREATE TABLE airlines (
    airline_id integer PRIMARY KEY,
    name       text,
    iata       text,
    country    text
);

CREATE TABLE routes (
    airline_id  integer REFERENCES airlines,
    airline     text,
    src_id      integer NOT NULL REFERENCES airports,
    dst_id      integer NOT NULL REFERENCES airports,
    distance_km integer NOT NULL CHECK (distance_km >= 0)
);

-- The primary key (src_id, dst_id) is itself a B-tree: it serves lookups by src_id (its leftmost
-- column), but not by dst_id alone (see the inbound_reach benchmark).
CREATE TABLE edges (
    src_id      integer NOT NULL REFERENCES airports,
    dst_id      integer NOT NULL REFERENCES airports,
    distance_km integer NOT NULL,
    PRIMARY KEY (src_id, dst_id)
);

-- Distances are whole kilometres (DuckDB stores them as rounded doubles).
-- source: routes = SELECT airline_id, airline, src_id, dst_id, distance_km::INTEGER FROM routes
-- source: edges = SELECT src_id, dst_id, distance_km::INTEGER FROM edges
