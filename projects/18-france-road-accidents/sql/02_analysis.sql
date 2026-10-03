-- name: grain_check
-- The fan-out trap: joining accidents to roads naively duplicates accidents.
SELECT (SELECT count(*) FROM accidents)                                         AS accidents,
       (SELECT count(*) FROM roads_raw)                                         AS road_rows,
       (SELECT count(DISTINCT Num_Acc) FROM roads_raw)                          AS accidents_in_roads,
       (SELECT count(*) FROM accidents a JOIN roads_raw r ON r.Num_Acc = a.accident_id) AS naive_join_rows,
       (SELECT count(*) FROM accidents a JOIN accident_road r USING (accident_id))       AS fixed_join_rows,
       (SELECT count(*) FROM people)                                            AS people,
       (SELECT count(*) FROM people WHERE severity IS NULL)                     AS people_unknown_severity;

-- name: severity
-- Everyone involved, by outcome.
SELECT severity, count(*) AS people, round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
FROM people
WHERE severity IS NOT NULL
GROUP BY severity
ORDER BY people DESC;

-- name: by_mode
-- How dangerous is each way of travelling? Deaths per 100 people involved in an accident.
SELECT mode,
       count(*)                                                                AS people_involved,
       count(*) FILTER (WHERE severity = 'Killed')                             AS killed,
       round(100.0 * count(*) FILTER (WHERE severity = 'Killed') / count(*), 2) AS killed_per_100_involved,
       round(100.0 * count(*) FILTER (WHERE severity IN ('Killed', 'Hospitalized')) / count(*), 1) AS killed_or_hospitalized_pct
FROM people_mode
WHERE severity IS NOT NULL AND mode IS NOT NULL
GROUP BY mode
HAVING count(*) >= 500
ORDER BY killed_per_100_involved DESC;

-- name: urban_vs_rural
-- Share of accidents vs share of deaths, inside and outside built-up areas.
WITH acc AS (
    SELECT a.area, count(DISTINCT a.accident_id) AS accidents,
           count(*) FILTER (WHERE p.severity = 'Killed') AS killed
    FROM accidents a JOIN people p USING (accident_id)
    WHERE a.area IS NOT NULL
    GROUP BY a.area
)
SELECT area, accidents, killed,
       round(100.0 * accidents / sum(accidents) OVER (), 1) AS accidents_pct,
       round(100.0 * killed / sum(killed) OVER (), 1)       AS deaths_pct,
       round(100.0 * killed / accidents, 1)                 AS killed_per_100_accidents
FROM acc
ORDER BY area;

-- name: by_road
-- Lethality by road type (one road per accident).
SELECT r.road_type,
       count(DISTINCT a.accident_id)                                                         AS accidents,
       count(*) FILTER (WHERE p.severity = 'Killed')                                         AS killed,
       round(100.0 * count(*) FILTER (WHERE p.severity = 'Killed') / count(DISTINCT a.accident_id), 1) AS killed_per_100_accidents
FROM accidents a
JOIN accident_road r USING (accident_id)
JOIN people p USING (accident_id)
GROUP BY r.road_type
ORDER BY killed_per_100_accidents DESC;

-- name: by_hour
-- Accidents and deaths by hour of the day.
SELECT a.hr,
       count(DISTINCT a.accident_id)                                        AS accidents,
       count(*) FILTER (WHERE p.severity = 'Killed')                        AS killed,
       round(100.0 * count(*) FILTER (WHERE p.severity = 'Killed') / count(DISTINCT a.accident_id), 1) AS killed_per_100_accidents
FROM accidents a JOIN people p USING (accident_id)
GROUP BY a.hr
ORDER BY a.hr;

-- name: by_age
-- Killed and hospitalized people by age band.
SELECT CASE WHEN age < 18 THEN '1. 0-17' WHEN age < 25 THEN '2. 18-24' WHEN age < 35 THEN '3. 25-34'
            WHEN age < 45 THEN '4. 35-44' WHEN age < 55 THEN '5. 45-54' WHEN age < 65 THEN '6. 55-64'
            WHEN age < 75 THEN '7. 65-74' ELSE '8. 75+' END                         AS age_band,
       count(*)                                                                    AS people_involved,
       count(*) FILTER (WHERE severity = 'Killed')                                 AS killed,
       round(100.0 * count(*) FILTER (WHERE severity = 'Killed') / count(*), 2)    AS killed_per_100_involved
FROM people
WHERE age BETWEEN 0 AND 110 AND severity IS NOT NULL
GROUP BY age_band
ORDER BY age_band;

-- name: seatbelt
-- Car occupants: death rate with and without a recorded seatbelt.
SELECT CASE WHEN wore_seatbelt THEN 'Seatbelt recorded' ELSE 'No seatbelt recorded' END AS seatbelt,
       count(*)                                                                  AS car_occupants,
       count(*) FILTER (WHERE severity = 'Killed')                               AS killed,
       round(100.0 * count(*) FILTER (WHERE severity = 'Killed') / count(*), 2)  AS killed_per_100
FROM people_mode
WHERE mode = 'Car' AND severity IS NOT NULL
GROUP BY seatbelt
ORDER BY seatbelt;

-- name: light
SELECT a.light,
       count(DISTINCT a.accident_id)                                                         AS accidents,
       round(100.0 * count(*) FILTER (WHERE p.severity = 'Killed') / count(DISTINCT a.accident_id), 1) AS killed_per_100_accidents
FROM accidents a JOIN people p USING (accident_id)
WHERE a.light IS NOT NULL
GROUP BY a.light
ORDER BY killed_per_100_accidents DESC;
