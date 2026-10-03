-- OpenFlights: airports, airlines and routes (route data frozen in June 2014).
-- Files have no header and use \N for NULL.

CREATE OR REPLACE TABLE airports AS
SELECT * FROM read_csv('data/airports.dat', header = false, nullstr = '\N', columns = {
    'airport_id': 'INTEGER', 'name': 'VARCHAR', 'city': 'VARCHAR', 'country': 'VARCHAR',
    'iata': 'VARCHAR', 'icao': 'VARCHAR', 'lat': 'DOUBLE', 'lon': 'DOUBLE', 'altitude_ft': 'INTEGER',
    'utc_offset': 'DOUBLE', 'dst': 'VARCHAR', 'tz': 'VARCHAR', 'type': 'VARCHAR', 'source': 'VARCHAR'});

CREATE OR REPLACE TABLE airlines AS
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
CREATE OR REPLACE TABLE routes AS
SELECT DISTINCT r.airline_id, r.airline, r.src_id, r.dst_id,
       round(haversine_km(a.lat, a.lon, b.lat, b.lon), 0) AS distance_km,
       a.country AS src_country, b.country AS dst_country
FROM routes_raw r
JOIN airports a ON a.airport_id = r.src_id
JOIN airports b ON b.airport_id = r.dst_id
WHERE r.stops = 0
  AND a.airport_id NOT IN (SELECT airport_id FROM airport_errors)
  AND b.airport_id NOT IN (SELECT airport_id FROM airport_errors);

-- Airport-to-airport graph, regardless of airline.
CREATE OR REPLACE TABLE edges AS
SELECT DISTINCT src_id, dst_id, distance_km FROM routes;
