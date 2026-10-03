-- F1DB: the open Formula 1 database (every championship race since 1950).

-- A 7-table model with enforced keys. Children are dropped first: DuckDB refuses to drop a table
-- that a foreign key still points to.
DROP TABLE IF EXISTS season_standings;
DROP TABLE IF EXISTS champions;
DROP TABLE IF EXISTS results;
DROP TABLE IF EXISTS races;
DROP TABLE IF EXISTS drivers;
DROP TABLE IF EXISTS constructors;
DROP TABLE IF EXISTS countries;

CREATE TABLE countries (
    country_id VARCHAR PRIMARY KEY,
    country    VARCHAR NOT NULL
);
INSERT INTO countries SELECT id, name FROM read_csv_auto('data/f1db-countries.csv');

CREATE TABLE drivers (
    driver_id  VARCHAR PRIMARY KEY,
    name       VARCHAR NOT NULL,
    country_id VARCHAR NOT NULL REFERENCES countries (country_id),
    born       DATE
);
INSERT INTO drivers
SELECT id, name, nationalityCountryId, dateOfBirth FROM read_csv_auto('data/f1db-drivers.csv');

CREATE TABLE constructors (
    constructor_id VARCHAR PRIMARY KEY,
    name           VARCHAR NOT NULL,
    country_id     VARCHAR NOT NULL REFERENCES countries (country_id)
);
INSERT INTO constructors SELECT id, name, countryId FROM read_csv_auto('data/f1db-constructors.csv');

CREATE TABLE races (
    race_id    INTEGER PRIMARY KEY,
    year       INTEGER NOT NULL CHECK (year >= 1950),
    round      INTEGER NOT NULL CHECK (round >= 1),
    date       DATE NOT NULL,
    grand_prix VARCHAR NOT NULL,
    circuit    VARCHAR NOT NULL,
    laps       INTEGER,
    UNIQUE (year, round)
);
INSERT INTO races
SELECT id, year, round, date, grandPrixId, circuitId, laps FROM read_csv_auto('data/f1db-races.csv');

-- One row per car classified or not. (race, driver) is NOT unique: in the 1950s team-mates shared
-- cars and both appear; the natural key is the race plus the row's display order.
CREATE TABLE results (
    race_id         INTEGER NOT NULL REFERENCES races (race_id),
    position_order  INTEGER NOT NULL,
    year            INTEGER NOT NULL,
    finish_position INTEGER CHECK (finish_position >= 1),
    position_text   VARCHAR NOT NULL,
    driver_id       VARCHAR NOT NULL REFERENCES drivers (driver_id),
    constructor_id  VARCHAR NOT NULL REFERENCES constructors (constructor_id),
    engine          VARCHAR,
    grid_position   INTEGER,
    laps            INTEGER,
    reason_retired  VARCHAR,
    points          DOUBLE,
    shared_car      BOOLEAN,
    PRIMARY KEY (race_id, position_order)
);
INSERT INTO results
SELECT raceId, positionDisplayOrder, year, positionNumber, positionText, driverId, constructorId,
       engineManufacturerId, gridPositionNumber, laps, reasonRetired, points, sharedCar
FROM read_csv_auto('data/f1db-races-race-results.csv');

-- Final championship table of every season.
CREATE TABLE season_standings (
    year          INTEGER NOT NULL,
    position      INTEGER NOT NULL,
    driver_id     VARCHAR NOT NULL REFERENCES drivers (driver_id),
    points        DOUBLE NOT NULL,
    champion      BOOLEAN NOT NULL,
    PRIMARY KEY (year, position)
);
INSERT INTO season_standings
SELECT year, positionDisplayOrder, driverId, points, championshipWon
FROM read_csv_auto('data/f1db-seasons-driver-standings.csv');

CREATE TABLE champions (
    year      INTEGER PRIMARY KEY,
    driver_id VARCHAR NOT NULL REFERENCES drivers (driver_id),
    points    DOUBLE NOT NULL
);
INSERT INTO champions SELECT year, driver_id, points FROM season_standings WHERE champion;

-- The calendar includes future races of the current season: keep only races that have results,
-- and flag the last season as incomplete.
CREATE OR REPLACE TABLE completed_races AS
SELECT r.* FROM races r WHERE EXISTS (SELECT 1 FROM results x WHERE x.race_id = r.race_id);

CREATE OR REPLACE TABLE wins AS
SELECT res.race_id, res.year, res.driver_id, res.constructor_id, res.grid_position
FROM results res
WHERE res.finish_position = 1;
