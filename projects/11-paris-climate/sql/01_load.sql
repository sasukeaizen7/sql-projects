-- Paris daily weather 1950-2025 from the Open-Meteo historical API (ERA5 reanalysis grid cell over Paris).
-- The file starts with 2 lines of location metadata and a blank line before the real header.

CREATE OR REPLACE TABLE daily AS
SELECT
    CAST(time AS DATE)                 AS day,
    year(CAST(time AS DATE))           AS year,
    month(CAST(time AS DATE))          AS month,
    "temperature_2m_max (°C)"          AS t_max,
    "temperature_2m_min (°C)"          AS t_min,
    "temperature_2m_mean (°C)"         AS t_mean,
    "precipitation_sum (mm)"           AS rain_mm
FROM read_csv('data/paris_daily_1950_2025.csv', skip = 3, header = true);

-- The reference climate: 1951-1980 averages per calendar month.
CREATE OR REPLACE TABLE baseline AS
SELECT month, avg(t_mean) AS t_mean_1951_1980
FROM daily
WHERE year BETWEEN 1951 AND 1980
GROUP BY month;
