-- name: data_quality
SELECT (SELECT count(*) FROM routes_raw)                                                    AS raw_routes,
       (SELECT count(*) FROM routes_raw WHERE src_id IS NULL OR dst_id IS NULL)              AS unknown_airport_id,
       (SELECT count(*) FROM routes_raw WHERE stops > 0)                                     AS with_stops,
       (SELECT count(*) FROM airport_errors)                                                 AS corrupted_airports,
       (SELECT count(*) FROM routes)                                                         AS clean_airline_routes,
       (SELECT count(*) FROM edges)                                                          AS airport_pairs,
       (SELECT count(DISTINCT src_id) FROM edges)                                            AS airports_with_departures;

-- name: airport_errors
SELECT name, city, country, icao, round(lat, 2) AS lat, round(lon, 2) AS lon FROM airport_errors ORDER BY name;

-- name: hubs
-- The best-connected airports: number of distinct nonstop destinations (out-degree).
SELECT a.iata, a.name, a.city, a.country,
       count(*)                          AS destinations,
       count(DISTINCT b.country)         AS countries_served
FROM edges e
JOIN airports a ON a.airport_id = e.src_id
JOIN airports b ON b.airport_id = e.dst_id
GROUP BY a.iata, a.name, a.city, a.country
ORDER BY destinations DESC
LIMIT 12;

-- name: airlines
-- Airlines with the largest route networks.
SELECT coalesce(al.name, r.airline) AS airline, al.country,
       count(*)                               AS routes,
       count(DISTINCT r.src_id)               AS airports_served,
       round(median(r.distance_km), 0)        AS median_route_km
FROM routes r
LEFT JOIN airlines al USING (airline_id)
GROUP BY ALL
ORDER BY routes DESC
LIMIT 10;

-- name: longest
-- The 10 longest nonstop routes (haversine distance).
SELECT a.iata || ' → ' || b.iata AS route, a.city AS from_city, b.city AS to_city,
       e.distance_km
FROM edges e
JOIN airports a ON a.airport_id = e.src_id
JOIN airports b ON b.airport_id = e.dst_id
WHERE e.src_id < e.dst_id                          -- count each pair once
ORDER BY e.distance_km DESC
LIMIT 10;

-- name: route_lengths
-- Distribution of nonstop route lengths.
SELECT CASE WHEN distance_km < 500 THEN '1. < 500 km'
            WHEN distance_km < 1500 THEN '2. 500-1,500 km'
            WHEN distance_km < 4000 THEN '3. 1,500-4,000 km'
            WHEN distance_km < 8000 THEN '4. 4,000-8,000 km'
            ELSE '5. 8,000+ km' END                    AS length_band,
       count(*)                                       AS airport_pairs,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
FROM edges
GROUP BY length_band
ORDER BY length_band;

-- name: reach_from_paris
-- Recursive CTE: how many airports can you reach from Paris (CDG + ORY) with 0, 1 and 2 connections?
WITH RECURSIVE reach(airport_id, legs) AS (
    SELECT airport_id, 0 FROM airports WHERE iata IN ('CDG', 'ORY')
    UNION
    SELECT e.dst_id, r.legs + 1
    FROM reach r
    JOIN edges e ON e.src_id = r.airport_id
    WHERE r.legs < 3
), first_reach AS (
    SELECT airport_id, min(legs) AS legs FROM reach GROUP BY airport_id
)
SELECT legs - 1                                                AS connections,
       count(*)                                                AS new_airports,
       sum(count(*)) OVER (ORDER BY legs)                      AS cumulative_airports,
       round(100.0 * sum(count(*)) OVER (ORDER BY legs)
             / (SELECT count(DISTINCT src_id) FROM edges), 1)  AS pct_of_network
FROM first_reach
WHERE legs > 0
GROUP BY legs
ORDER BY legs;

-- name: paris_routes
-- Every nonstop destination from Paris (for the map).
SELECT a.iata AS origin, b.iata AS destination, b.city, b.country, b.lat, b.lon, e.distance_km
FROM edges e
JOIN airports a ON a.airport_id = e.src_id
JOIN airports b ON b.airport_id = e.dst_id
WHERE a.iata IN ('CDG', 'ORY');

-- name: domestic_share
-- Share of domestic routes by country (countries with 200+ routes).
SELECT src_country AS country, count(*) AS routes,
       round(100.0 * avg((src_country = dst_country)::INT), 1) AS domestic_pct
FROM routes
GROUP BY src_country
HAVING count(*) >= 200
ORDER BY routes DESC
LIMIT 12;
