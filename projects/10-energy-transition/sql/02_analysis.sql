-- name: world_mix
-- World electricity mix every year since 2000, grouped into 4 families (sums to ~100%).
SELECT year,
       round(sum(share_pct) FILTER (WHERE source IN ('coal', 'gas', 'oil')), 1)                   AS fossil_pct,
       round(sum(share_pct) FILTER (WHERE source = 'nuclear'), 1)                                AS nuclear_pct,
       round(sum(share_pct) FILTER (WHERE source IN ('hydro', 'other_renewables')), 1)           AS hydro_other_pct,
       round(sum(share_pct) FILTER (WHERE source IN ('wind', 'solar')), 1)                       AS wind_solar_pct
FROM elec_mix
WHERE country = 'World' AND year >= 2000
GROUP BY year
ORDER BY year;

-- name: solar_wind_growth
-- World wind and solar share, with year-over-year growth in percentage points (LAG).
SELECT year, source,
       round(share_pct, 2)                                                         AS share_pct,
       round(share_pct - lag(share_pct) OVER (PARTITION BY source ORDER BY year), 2) AS change_pp
FROM elec_mix
WHERE country = 'World' AND source IN ('wind', 'solar') AND year >= 2010
ORDER BY source, year;

-- name: low_carbon_leaders
-- Countries of 10M+ people with the cleanest electricity in 2024 (renewables + nuclear).
SELECT country, round(low_carbon_share_elec, 1) AS low_carbon_pct, round(renewables_share_elec, 1) AS renewables_pct,
       round(carbon_intensity_elec, 0) AS g_co2_per_kwh, round(generation_twh, 0) AS generation_twh
FROM country_year
WHERE year = 2024 AND population >= 10e6 AND low_carbon_share_elec IS NOT NULL
ORDER BY low_carbon_share_elec DESC
LIMIT 12;

-- name: fastest_wind_solar
-- Biggest jump in wind + solar share of electricity, 2015 -> 2024 (countries of 10M+ people).
SELECT country,
       round(max(wind_solar_share_elec) FILTER (WHERE year = 2015), 1)                               AS share_2015,
       round(max(wind_solar_share_elec) FILTER (WHERE year = 2024), 1)                               AS share_2024,
       round(max(wind_solar_share_elec) FILTER (WHERE year = 2024) - max(wind_solar_share_elec) FILTER (WHERE year = 2015), 1) AS gain_pp
FROM country_year
WHERE country IN (SELECT country FROM country_year WHERE year = 2024 AND population >= 10e6)
GROUP BY country
HAVING gain_pp IS NOT NULL
ORDER BY gain_pp DESC
LIMIT 12;

-- name: coal_exit
-- Largest drops in coal's share of electricity since 2010 (countries that used at least 20% coal in 2010).
SELECT country,
       round(max(coal_share_elec) FILTER (WHERE year = 2010), 1)                                   AS coal_2010,
       round(max(coal_share_elec) FILTER (WHERE year = 2024), 1)                                   AS coal_2024,
       round(max(coal_share_elec) FILTER (WHERE year = 2024) - max(coal_share_elec) FILTER (WHERE year = 2010), 1) AS change_pp
FROM country_year
GROUP BY country
HAVING max(coal_share_elec) FILTER (WHERE year = 2010) >= 20 AND change_pp IS NOT NULL
ORDER BY change_pp
LIMIT 10;

-- name: europe_intensity
-- Carbon intensity of electricity (g CO2/kWh): France vs neighbours, 2000-2024.
SELECT year, country, round(carbon_intensity_elec, 0) AS g_co2_per_kwh
FROM country_year
WHERE country IN ('France', 'Germany', 'United Kingdom') AND year BETWEEN 2000 AND 2024
ORDER BY country, year;
