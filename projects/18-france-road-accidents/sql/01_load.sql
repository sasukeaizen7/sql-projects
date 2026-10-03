-- BAAC 2024: every road accident with casualties recorded by French police, in 4 related files.
--   caract   : one row per accident (when, where, light, weather)
--   lieux    : the road(s) involved -- can be SEVERAL rows per accident
--   vehicules: one row per vehicle
--   usagers  : one row per person involved, with injury severity
-- Codes follow the ONISR documentation; -1 means "not specified".

CREATE OR REPLACE MACRO baac(f) AS TABLE
    SELECT * FROM read_csv(f, delim = ';', header = true, all_varchar = true, quote = '"');

CREATE OR REPLACE TABLE accidents AS
SELECT Num_Acc AS accident_id,
       make_date(CAST(an AS INTEGER), CAST(mois AS INTEGER), CAST(jour AS INTEGER)) AS accident_date,
       CAST(split_part(hrmn, ':', 1) AS INTEGER)                              AS hr,
       CASE lum WHEN '1' THEN 'Daylight' WHEN '2' THEN 'Dusk or dawn' WHEN '3' THEN 'Night, no street lights'
                WHEN '4' THEN 'Night, lights off' WHEN '5' THEN 'Night, lights on' END AS light,
       dep AS department,
       CASE agg WHEN '1' THEN 'Outside built-up areas' WHEN '2' THEN 'Built-up areas' END AS area,
       CASE atm WHEN '1' THEN 'Normal' WHEN '2' THEN 'Light rain' WHEN '3' THEN 'Heavy rain' WHEN '4' THEN 'Snow / hail'
                WHEN '5' THEN 'Fog' WHEN '6' THEN 'Strong wind' WHEN '7' THEN 'Dazzling' WHEN '8' THEN 'Overcast' ELSE 'Other / unknown' END AS weather,
       TRY_CAST(replace(lat, ',', '.') AS DOUBLE)                              AS lat,
       TRY_CAST(replace(long, ',', '.') AS DOUBLE)                             AS lon
FROM baac('data/caract-2024.csv');

-- Roads: keep ONE row per accident (the first listed) to avoid duplicating accidents in joins.
CREATE OR REPLACE TABLE roads_raw AS SELECT * FROM baac('data/lieux-2024.csv');
CREATE OR REPLACE TABLE accident_road AS
SELECT Num_Acc AS accident_id,
       CASE catr WHEN '1' THEN 'Motorway' WHEN '2' THEN 'National road' WHEN '3' THEN 'Departmental road'
                 WHEN '4' THEN 'Municipal road' WHEN '7' THEN 'Metropolitan road' ELSE 'Other / car park' END AS road_type,
       TRY_CAST(vma AS INTEGER) AS speed_limit
FROM roads_raw
QUALIFY row_number() OVER (PARTITION BY Num_Acc ORDER BY Num_Acc) = 1;

CREATE OR REPLACE TABLE vehicles AS
SELECT Num_Acc AS accident_id, trim(id_vehicule) AS vehicle_id, num_veh,
       CASE WHEN catv IN ('7') THEN 'Car'
            WHEN catv IN ('2', '30', '31', '32', '33', '34', '35', '36', '41', '42', '43') THEN 'Motorbike / moped'
            WHEN catv IN ('1', '80') THEN 'Bicycle / e-bike'
            WHEN catv IN ('50', '60') THEN 'E-scooter / personal device'
            WHEN catv IN ('10') THEN 'Van'
            WHEN catv IN ('13', '14', '15', '16', '17') THEN 'Truck'
            WHEN catv IN ('37', '38') THEN 'Bus / coach'
            ELSE 'Other' END AS vehicle_type
FROM baac('data/vehicules-2024.csv');

CREATE OR REPLACE TABLE people AS
SELECT u.Num_Acc AS accident_id, trim(u.id_usager) AS person_id, trim(u.id_vehicule) AS vehicle_id,
       CASE u.catu WHEN '1' THEN 'Driver' WHEN '2' THEN 'Passenger' WHEN '3' THEN 'Pedestrian' END AS role,
       CASE u.grav WHEN '1' THEN 'Unhurt' WHEN '2' THEN 'Killed' WHEN '3' THEN 'Hospitalized' WHEN '4' THEN 'Minor injury' END AS severity,
       CASE u.sexe WHEN '1' THEN 'Male' WHEN '2' THEN 'Female' END AS sex,
       2024 - TRY_CAST(u.an_nais AS INTEGER) AS age,
       '1' IN (trim(u.secu1), trim(u.secu2), trim(u.secu3)) AS wore_seatbelt
FROM baac('data/usagers-2024.csv') u;

-- Each person with the mode of travel that matters for risk: pedestrians are on foot, others ride their vehicle.
CREATE OR REPLACE TABLE people_mode AS
SELECT p.*, CASE WHEN p.role = 'Pedestrian' THEN 'Pedestrian' ELSE v.vehicle_type END AS mode
FROM people p
LEFT JOIN vehicles v ON v.accident_id = p.accident_id AND v.vehicle_id = p.vehicle_id;
