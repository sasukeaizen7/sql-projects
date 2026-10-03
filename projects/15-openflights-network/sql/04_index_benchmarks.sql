-- Index benchmarks on the OpenFlights graph in PostgreSQL (run by toolkit/postgres.py).
-- Each query is timed with the primary/unique keys only, then after creating the index(es) listed in
-- its "-- index:" lines; the result must not change. Indexes are dropped between queries.

-- name: outbound_reach
-- Reference: airports reachable from Paris-CDG in at most 2 flights (recursive CTE). No index needed:
-- each step looks edges up by src_id, the leftmost column of the primary key (src_id, dst_id).
WITH RECURSIVE reach(airport_id, legs) AS (
    SELECT airport_id, 0 FROM airports WHERE iata = 'CDG'
    UNION
    SELECT e.dst_id, r.legs + 1
    FROM reach r JOIN edges e ON e.src_id = r.airport_id
    WHERE r.legs < 2
)
SELECT legs, count(DISTINCT airport_id) AS airports FROM reach GROUP BY legs ORDER BY legs;

-- name: inbound_reach
-- The reverse question: airports that can reach Paris-CDG in at most 2 flights. Now each step looks
-- edges up by dst_id, which the primary key can't serve; the reversed composite index can.
-- index: CREATE INDEX edges_dst_src ON edges (dst_id, src_id)
WITH RECURSIVE reach(airport_id, legs) AS (
    SELECT airport_id, 0 FROM airports WHERE iata = 'CDG'
    UNION
    SELECT e.src_id, r.legs + 1
    FROM reach r JOIN edges e ON e.dst_id = r.airport_id
    WHERE r.legs < 2
)
SELECT legs, count(DISTINCT airport_id) AS airports FROM reach GROUP BY legs ORDER BY legs;

-- name: nearest_airports
-- The 5 airports closest to the Eiffel Tower. ORDER BY distance LIMIT 5 is a k-nearest-neighbour
-- search: a GiST index walks the space outward from the point instead of sorting every airport.
-- index: CREATE INDEX airports_earth ON airports USING gist (ll_to_earth(lat, lon))
SELECT iata, name, city,
       round((earth_distance(ll_to_earth(lat, lon), ll_to_earth(48.8584, 2.2945)) / 1000)::numeric, 1) AS km
FROM airports
ORDER BY ll_to_earth(lat, lon) <-> ll_to_earth(48.8584, 2.2945), airport_id
LIMIT 5;

-- name: radius_search
-- Every airport within 100 km of Frankfurt: earth_box() is a bounding cube the GiST index can search,
-- and earth_distance() then trims its corners to an exact circle.
-- index: CREATE INDEX airports_earth ON airports USING gist (ll_to_earth(lat, lon))
SELECT iata, name, city
FROM airports
WHERE earth_box(ll_to_earth(50.0333, 8.5706), 100000) @> ll_to_earth(lat, lon)
  AND earth_distance(ll_to_earth(50.0333, 8.5706), ll_to_earth(lat, lon)) <= 100000
ORDER BY airport_id;

-- name: airline_network
-- Every route of one airline, found by airline name through the foreign key. Postgres does not index
-- foreign keys: without this index the join reads all 66k routes.
-- index: CREATE INDEX routes_airline ON routes (airline_id)
SELECT a.iata AS origin, b.iata AS destination, r.distance_km
FROM airlines al
JOIN routes r   ON r.airline_id = al.airline_id
JOIN airports a ON a.airport_id = r.src_id
JOIN airports b ON b.airport_id = r.dst_id
WHERE al.name = 'Air Tahiti Nui'
ORDER BY origin, destination;
