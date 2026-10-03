-- F1DB: the open Formula 1 database (every championship race since 1950).

CREATE OR REPLACE TABLE countries AS
SELECT id AS country_id, name AS country FROM read_csv_auto('data/f1db-countries.csv');

CREATE OR REPLACE TABLE drivers AS
SELECT id AS driver_id, name, nationalityCountryId AS country_id, dateOfBirth AS born
FROM read_csv_auto('data/f1db-drivers.csv');

CREATE OR REPLACE TABLE constructors AS
SELECT id AS constructor_id, name, countryId AS country_id FROM read_csv_auto('data/f1db-constructors.csv');

CREATE OR REPLACE TABLE races AS
SELECT id AS race_id, year, round, date, grandPrixId AS grand_prix, circuitId AS circuit, laps
FROM read_csv_auto('data/f1db-races.csv');

CREATE OR REPLACE TABLE results AS
SELECT raceId AS race_id, year, positionNumber AS finish_position, positionText AS position_text,
       driverId AS driver_id, constructorId AS constructor_id, engineManufacturerId AS engine,
       gridPositionNumber AS grid_position, laps, reasonRetired AS reason_retired, points,
       sharedCar AS shared_car
FROM read_csv_auto('data/f1db-races-race-results.csv');

CREATE OR REPLACE TABLE champions AS
SELECT year, driverId AS driver_id, points
FROM read_csv_auto('data/f1db-seasons-driver-standings.csv')
WHERE championshipWon;

-- The calendar includes future races of the current season: keep only races that have results,
-- and flag the last season as incomplete.
CREATE OR REPLACE TABLE completed_races AS
SELECT r.* FROM races r WHERE EXISTS (SELECT 1 FROM results x WHERE x.race_id = r.race_id);

CREATE OR REPLACE TABLE wins AS
SELECT res.race_id, res.year, res.driver_id, res.constructor_id, res.grid_position
FROM results res
WHERE res.finish_position = 1;
