-- name: snapshot
-- When was the snapshot taken, and how healthy is the station feed?
SELECT any_value(snapshot_at)                                         AS snapshot_at,
       count(*)                                                       AS stations,
       count(*) FILTER (WHERE status = 'ok')                          AS active,
       count(*) FILTER (WHERE status = 'closed (not renting)')        AS closed,
       count(*) FILTER (WHERE last_report_at < snapshot_at - INTERVAL 1 DAY) AS no_report_24h,
       min(last_report_at)                                             AS oldest_report
FROM stations;

-- name: network
-- Network size and bikes available right now, Paris vs suburbs.
SELECT CASE WHEN in_paris THEN 'Paris' ELSE 'Suburbs' END        AS area,
       count(*)                                                  AS stations,
       sum(capacity)                                             AS docks,
       sum(bikes)                                                AS bikes_available,
       round(100.0 * sum(ebike) / nullif(sum(bikes), 0), 1)     AS ebike_share_pct,
       round(100.0 * sum(bikes) / sum(capacity), 1)             AS fill_pct,
       round(100.0 * avg(is_empty::INT), 1)                     AS empty_stations_pct,
       round(100.0 * avg(is_full::INT), 1)                      AS full_stations_pct
FROM active_stations
GROUP BY area
ORDER BY area;

-- name: by_arrondissement
-- Fill rate per Paris arrondissement: where are bikes piling up, where are they missing?
SELECT arrondissement,
       count(*)                                            AS stations,
       sum(bikes)                                          AS bikes,
       sum(capacity)                                       AS docks,
       round(100.0 * sum(bikes) / sum(capacity), 1)        AS fill_pct,
       round(100.0 * avg(is_empty::INT), 1)                AS empty_stations_pct
FROM active_stations
WHERE arrondissement IS NOT NULL
GROUP BY arrondissement
ORDER BY arrondissement;

-- name: suburbs
-- Communes outside Paris with the most stations.
SELECT commune, count(*) AS stations, sum(capacity) AS docks,
       round(100.0 * sum(bikes) / sum(capacity), 1) AS fill_pct
FROM active_stations
WHERE NOT in_paris
GROUP BY commune
ORDER BY stations DESC
LIMIT 10;

-- name: station_map
-- Every active station with its fill rate (for the map).
SELECT station_code, name, lat, lon, capacity, bikes, round(fill_rate, 3) AS fill_rate, in_paris, arrondissement
FROM active_stations
ORDER BY station_code;

-- name: largest
-- The biggest stations and how full they are.
SELECT name, commune, capacity, bikes, free_docks, round(100.0 * fill_rate, 0) AS fill_pct
FROM active_stations
ORDER BY capacity DESC
LIMIT 10;
