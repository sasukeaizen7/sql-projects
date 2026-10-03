-- Our World in Data energy dataset: electricity mix and energy use by country and year.

CREATE OR REPLACE TABLE energy_raw AS
SELECT * FROM read_csv_auto('data/owid-energy-data.csv');

-- Electricity mix in long format (one row per country, year and source): easier to aggregate and chart.
CREATE OR REPLACE TABLE elec_mix AS
UNPIVOT (
    SELECT country, iso_code, year,
           coal_share_elec, gas_share_elec, oil_share_elec, nuclear_share_elec,
           hydro_share_elec, wind_share_elec, solar_share_elec, other_renewables_share_elec
    FROM energy_raw
)
ON coal_share_elec, gas_share_elec, oil_share_elec, nuclear_share_elec,
   hydro_share_elec, wind_share_elec, solar_share_elec, other_renewables_share_elec
INTO NAME source VALUE share_pct;

UPDATE elec_mix SET source = replace(source, '_share_elec', '');

-- Countries only (aggregates have no ISO code or an OWID_ code), with the indicators used below.
CREATE OR REPLACE TABLE country_year AS
SELECT country, iso_code, year, population, electricity_generation AS generation_twh,
       renewables_share_elec, low_carbon_share_elec, fossil_share_elec,
       coalesce(wind_share_elec, 0) + coalesce(solar_share_elec, 0) AS wind_solar_share_elec,
       coal_share_elec, carbon_intensity_elec
FROM energy_raw
WHERE iso_code IS NOT NULL AND iso_code NOT LIKE 'OWID%';
