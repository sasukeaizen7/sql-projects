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
WHERE a.iata IN ('CDG', 'ORY')
ORDER BY a.iata, b.iata;

-- name: domestic_share
-- Share of domestic routes by country (countries with 200+ routes).
SELECT src_country AS country, count(*) AS routes,
       round(100.0 * avg((src_country = dst_country)::INT), 1) AS domestic_pct
FROM routes
GROUP BY src_country
HAVING count(*) >= 200
ORDER BY routes DESC
LIMIT 12;

-- ============================================================================================
-- Advanced SQL (the shortest-path view shortest_from_cdg is built in sql/01_load.sql)
-- ============================================================================================

-- name: shortest_itineraries
-- The shortest flying route from Paris-CDG to remote places, with the itinerary rebuilt from the path.
SELECT city, country, legs,
       round(km, 0)                                   AS flown_km,
       round(straight_km, 0)                          AS straight_km,
       round(greatest(100.0 * (km / straight_km - 1), 0), 1) AS detour_pct,
       array_to_string(path, ' → ')                   AS itinerary
FROM shortest_from_cdg
WHERE iata IN ('SYD', 'AKL', 'IPC', 'HNL', 'USH', 'LYR', 'PPT', 'MLE', 'ANC', 'CPT')
ORDER BY flown_km DESC;

-- name: detour_by_legs
-- How much longer than a straight line is the shortest flying route, by number of legs?
SELECT legs,
       count(*)                                                       AS airports,
       round(greatest(median(100.0 * (km / straight_km - 1)), 0), 1) AS median_detour_pct,
       round(quantile_cont(100.0 * (km / straight_km - 1), 0.9), 1)   AS p90_detour_pct,
       round(median(km), 0)                                           AS median_flown_km
FROM shortest_from_cdg
WHERE legs > 0
GROUP BY legs
ORDER BY legs;

-- name: country_hubs
-- The 3 biggest hubs of each of the 8 countries with the most departing routes: the LATERAL subquery is evaluated
-- for each country row and returns its own top 3.
SELECT c.country, h.rank, h.iata, h.city, h.destinations, h.domestic_pct
FROM (SELECT src_country AS country, count(*) AS routes
      FROM routes GROUP BY 1 ORDER BY routes DESC LIMIT 8) c,
LATERAL (
    SELECT row_number() OVER (ORDER BY count(*) DESC, a.iata) AS rank,
           a.iata, a.city,
           count(*) AS destinations,
           round(100.0 * avg((b.country = a.country)::INT), 0) AS domestic_pct
    FROM edges e
    JOIN airports a ON a.airport_id = e.src_id
    JOIN airports b ON b.airport_id = e.dst_id
    WHERE a.country = c.country
    GROUP BY a.iata, a.city
    ORDER BY destinations DESC, a.iata
    LIMIT 3
) h
ORDER BY c.routes DESC, h.rank;

-- name: one_way_routes
-- Routes flown in one direction only (anti-join on the reverse edge). Most are "triangle" routings:
-- the return goes through a third airport (EXISTS on a 2-leg path back).
WITH one_way AS (
    SELECT e.src_id, e.dst_id, e.distance_km
    FROM edges e
    WHERE NOT EXISTS (SELECT 1 FROM edges r WHERE r.src_id = e.dst_id AND r.dst_id = e.src_id)
)
SELECT count(*)                                                                       AS one_way_routes,
       round(100.0 * count(*) / (SELECT count(*) FROM edges), 1)                      AS pct_of_routes,
       count(*) FILTER (WHERE EXISTS (
           SELECT 1 FROM edges r1 JOIN edges r2 ON r2.src_id = r1.dst_id
           WHERE r1.src_id = o.dst_id AND r2.dst_id = o.src_id))                      AS return_in_two_legs,
       round(median(distance_km), 0)                                                  AS median_km
FROM one_way o;
