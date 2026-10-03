-- Our World in Data CO2 dataset: one row per country (or region) and year, 1750-2024.

CREATE OR REPLACE TABLE owid_raw AS
SELECT * FROM read_csv_auto('data/owid-co2-data.csv');

-- Countries and aggregates (World, continents, income groups) share the same table.
-- Summing them together would count emissions several times, so split them explicitly.
CREATE OR REPLACE TABLE country_year AS
SELECT country, iso_code, year, population, gdp,
       co2, co2_per_capita, cumulative_co2, share_global_co2,
       coal_co2, oil_co2, gas_co2, cement_co2, consumption_co2, trade_co2
FROM owid_raw
WHERE iso_code IS NOT NULL AND iso_code NOT LIKE 'OWID%';

CREATE OR REPLACE TABLE world_year AS
SELECT year, population, co2, coal_co2, oil_co2, gas_co2, cement_co2, co2_per_capita
FROM owid_raw
WHERE country = 'World';
