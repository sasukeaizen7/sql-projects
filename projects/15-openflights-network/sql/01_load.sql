-- OpenFlights: airports, airlines and routes (route data frozen in June 2014).
-- Files have no header and use \N for NULL.
-- Tables get primary, unique and foreign keys. DuckDB refuses to replace a table that a foreign key
-- points to, so dependent objects are dropped first.
DROP VIEW IF EXISTS shortest_from_cdg;
DROP TABLE IF EXISTS edges;
DROP TABLE IF EXISTS routes;
DROP TABLE IF EXISTS airlines;
DROP TABLE IF EXISTS airports;

CREATE TABLE airports (
    airport_id  INTEGER PRIMARY KEY,
    name        VARCHAR,
    city        VARCHAR,
    country     VARCHAR,
    iata        VARCHAR UNIQUE,
    icao        VARCHAR,
    lat         DOUBLE NOT NULL CHECK (lat BETWEEN -90 AND 90),
    lon         DOUBLE NOT NULL CHECK (lon BETWEEN -180 AND 180),
    altitude_ft INTEGER,
    utc_offset  DOUBLE,
    dst         VARCHAR,
    tz          VARCHAR,
    type        VARCHAR,
    source      VARCHAR
);
INSERT INTO airports
SELECT * FROM read_csv('data/airports.dat', header = false, nullstr = '\N', columns = {
    'airport_id': 'INTEGER', 'name': 'VARCHAR', 'city': 'VARCHAR', 'country': 'VARCHAR',
    'iata': 'VARCHAR', 'icao': 'VARCHAR', 'lat': 'DOUBLE', 'lon': 'DOUBLE', 'altitude_ft': 'INTEGER',
    'utc_offset': 'DOUBLE', 'dst': 'VARCHAR', 'tz': 'VARCHAR', 'type': 'VARCHAR', 'source': 'VARCHAR'});

CREATE TABLE airlines (
    airline_id INTEGER PRIMARY KEY,
    name       VARCHAR,
    alias      VARCHAR,
    iata       VARCHAR,
    icao       VARCHAR,
    callsign   VARCHAR,
    country    VARCHAR,
    active     VARCHAR
);
INSERT INTO airlines
SELECT * FROM read_csv('data/airlines.dat', header = false, nullstr = '\N', columns = {
    'airline_id': 'INTEGER', 'name': 'VARCHAR', 'alias': 'VARCHAR', 'iata': 'VARCHAR', 'icao': 'VARCHAR',
    'callsign': 'VARCHAR', 'country': 'VARCHAR', 'active': 'VARCHAR'});

CREATE OR REPLACE TABLE routes_raw AS
SELECT * FROM read_csv('data/routes.dat', header = false, nullstr = '\N', columns = {
    'airline': 'VARCHAR', 'airline_id': 'INTEGER', 'src': 'VARCHAR', 'src_id': 'INTEGER',
    'dst': 'VARCHAR', 'dst_id': 'INTEGER', 'codeshare': 'VARCHAR', 'stops': 'INTEGER', 'equipment': 'VARCHAR'});

-- Great-circle distance in km (haversine) as a reusable macro.
CREATE OR REPLACE MACRO haversine_km(lat1, lon1, lat2, lon2) AS
    2 * 6371 * asin(sqrt(
        pow(sin(radians(lat2 - lat1) / 2), 2) +
        cos(radians(lat1)) * cos(radians(lat2)) * pow(sin(radians(lon2 - lon1) / 2), 2)));

-- Corrupted records: US airports (ICAO K___ / PA__, US coordinates) whose city and country were
-- overwritten with foreign ones, e.g. "Los Alamitos Army Air Field, Solwesi, Zambia". They create
-- impossible routes (a 16,082 km "domestic" Zambian flight), so they are excluded.
CREATE OR REPLACE TABLE airport_errors AS
SELECT airport_id, name, city, country, icao, lat, lon
FROM airports
WHERE regexp_matches(icao, '^(K[A-Z0-9]{3}|PA[A-Z]{2})$') AND country <> 'United States';

-- Clean routes: both airports known and valid, nonstop, and one row per airline + airport pair.
-- 455 routes have no airline id: the foreign key allows NULL, but any id given must exist.
CREATE TABLE routes (
    airline_id  INTEGER REFERENCES airlines (airline_id),
    airline     VARCHAR,
    src_id      INTEGER NOT NULL REFERENCES airports (airport_id),
    dst_id      INTEGER NOT NULL REFERENCES airports (airport_id),
    distance_km DOUBLE NOT NULL CHECK (distance_km >= 0),
    src_country VARCHAR,
    dst_country VARCHAR,
    UNIQUE (airline_id, airline, src_id, dst_id)
);
INSERT INTO routes
SELECT DISTINCT r.airline_id, r.airline, r.src_id, r.dst_id,
       round(haversine_km(a.lat, a.lon, b.lat, b.lon), 0) AS distance_km,
       a.country AS src_country, b.country AS dst_country
FROM routes_raw r
JOIN airports a ON a.airport_id = r.src_id
JOIN airports b ON b.airport_id = r.dst_id
WHERE r.stops = 0
  AND a.airport_id NOT IN (SELECT airport_id FROM airport_errors)
  AND b.airport_id NOT IN (SELECT airport_id FROM airport_errors);

-- Airport-to-airport graph, regardless of airline: one row per directed edge.
CREATE TABLE edges (
    src_id      INTEGER NOT NULL REFERENCES airports (airport_id),
    dst_id      INTEGER NOT NULL REFERENCES airports (airport_id),
    distance_km DOUBLE NOT NULL,
    PRIMARY KEY (src_id, dst_id)
);
INSERT INTO edges
SELECT DISTINCT src_id, dst_id, distance_km FROM routes;

-- Shortest flying distance from Paris-CDG to every reachable airport (Bellman-Ford in SQL).
-- USING KEY (DuckDB 1.3+) turns the recursive CTE into a dictionary keyed by airport: a row is only
-- re-emitted when a shorter distance is found, and `recurring.sp` reads the best distance so far.
-- The recursion stops when no distance improves. Checked against a Dijkstra in Python: same 3,164
-- airports, same distances. Used by the shortest_itineraries and detour_by_legs queries.
CREATE OR REPLACE VIEW shortest_from_cdg AS
WITH RECURSIVE sp(airport_id, km, legs, path) USING KEY (airport_id) AS (
    SELECT airport_id, 0::DOUBLE, 0, [iata] FROM airports WHERE iata = 'CDG'
    UNION
    -- Exact (unrounded) leg lengths: with whole-km distances, a nearly straight 2-leg path could look
    -- up to 1 km shorter than the direct flight.
    SELECT e.dst_id,
           min(sp.km + haversine_km(a.lat, a.lon, b.lat, b.lon)),
           arg_min(sp.legs + 1, sp.km + haversine_km(a.lat, a.lon, b.lat, b.lon)),
           arg_min(list_append(sp.path, b.iata), sp.km + haversine_km(a.lat, a.lon, b.lat, b.lon))  -- the itinerary
    FROM sp
    JOIN edges e    ON e.src_id = sp.airport_id
    JOIN airports a ON a.airport_id = e.src_id
    JOIN airports b ON b.airport_id = e.dst_id
    LEFT JOIN recurring.sp best ON best.airport_id = e.dst_id
    GROUP BY e.dst_id
    HAVING min(sp.km + haversine_km(a.lat, a.lon, b.lat, b.lon)) < coalesce(min(best.km), 'infinity'::DOUBLE) - 1e-6
)
SELECT sp.*, a.iata, a.name, a.city, a.country,
       haversine_km(o.lat, o.lon, a.lat, a.lon) AS straight_km
FROM sp
JOIN airports a ON a.airport_id = sp.airport_id
CROSS JOIN (SELECT lat, lon FROM airports WHERE iata = 'CDG') o;
