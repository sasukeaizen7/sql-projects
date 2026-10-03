-- Vélib' Métropole real-time availability: one row per station, captured at download time.

CREATE OR REPLACE TABLE stations_raw AS
SELECT * FROM read_csv('data/velib_status.csv', delim = ';', header = true);

CREATE OR REPLACE TABLE stations AS
WITH snap AS (SELECT max(duedate) AS ts FROM stations_raw)
SELECT
    stationcode                                                         AS station_code,
    name,
    nom_arrondissement_communes                                         AS commune,
    code_insee_commune = '75056'                                        AS in_paris,
    -- Paris station codes start with the arrondissement number (e.g. 11104 -> 11e).
    CASE WHEN code_insee_commune = '75056' AND CAST(stationcode AS INTEGER) // 1000 BETWEEN 1 AND 20
         THEN CAST(stationcode AS INTEGER) // 1000 END                  AS arrondissement,
    capacity,
    numbikesavailable                                                   AS bikes,
    mechanical,
    ebike,
    numdocksavailable                                                   AS free_docks,
    CAST(split_part(coordonnees_geo, ',', 1) AS DOUBLE)                 AS lat,
    CAST(split_part(coordonnees_geo, ',', 2) AS DOUBLE)                 AS lon,
    duedate                                                             AS last_report_at,
    (SELECT ts FROM snap)                                               AS snapshot_at,
    CASE
        WHEN is_installed <> 'OUI'                                      THEN 'not installed'
        WHEN is_renting <> 'OUI'                                        THEN 'closed (not renting)'
        WHEN duedate < (SELECT ts FROM snap) - INTERVAL 1 DAY           THEN 'stale (no report for 24h+)'
        WHEN capacity = 0                                               THEN 'zero capacity'
        ELSE 'ok'
    END                                                                 AS status
FROM stations_raw;

CREATE OR REPLACE TABLE active_stations AS
SELECT *,
       bikes::DOUBLE / capacity                                         AS fill_rate,
       bikes = 0                                                        AS is_empty,
       free_docks = 0                                                   AS is_full
FROM stations
WHERE status = 'ok';
