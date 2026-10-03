-- name: data_quality
-- From raw rows to clean apartment sales: what was excluded and why.
SELECT quality,
       count(*)                                            AS sales,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1)  AS pct
FROM sale_quality
GROUP BY quality
ORDER BY sales DESC;

-- name: citywide
-- Paris-wide price per m² distribution, per year (percentiles).
SELECT year,
       count(*)                                                   AS sales,
       round(quantile_cont(price_m2, 0.10), 0)                    AS p10_eur_m2,
       round(median(price_m2), 0)                                 AS median_eur_m2,
       round(quantile_cont(price_m2, 0.90), 0)                    AS p90_eur_m2,
       round(median(price_eur), 0)                                AS median_price_eur,
       round(median(living_m2), 1)                                AS median_m2
FROM apartment_sales
GROUP BY year
ORDER BY year;

-- name: by_arrondissement
-- Median €/m² per arrondissement in 2024, and change vs 2023 (pivot with FILTER).
SELECT arrondissement,
       count(*) FILTER (WHERE year = 2024)                                 AS sales_2024,
       round(median(price_m2) FILTER (WHERE year = 2023), 0)              AS median_m2_2023,
       round(median(price_m2) FILTER (WHERE year = 2024), 0)              AS median_m2_2024,
       round(100.0 * (median(price_m2) FILTER (WHERE year = 2024)
                      / median(price_m2) FILTER (WHERE year = 2023) - 1), 1) AS change_pct,
       rank() OVER (ORDER BY median(price_m2) FILTER (WHERE year = 2024) DESC) AS rank_2024
FROM apartment_sales
GROUP BY arrondissement
ORDER BY arrondissement;

-- name: by_size
-- Are small flats more expensive per m²? (2024)
SELECT CASE WHEN living_m2 < 20 THEN '1: < 20 m²'
            WHEN living_m2 < 40 THEN '2: 20-40 m²'
            WHEN living_m2 < 70 THEN '3: 40-70 m²'
            WHEN living_m2 < 100 THEN '4: 70-100 m²'
            ELSE '5: 100+ m²' END                     AS size_band,
       count(*)                                        AS sales,
       round(median(price_m2), 0)                      AS median_eur_m2,
       round(median(price_eur), 0)                     AS median_price_eur
FROM apartment_sales
WHERE year = 2024
GROUP BY size_band
ORDER BY size_band;

-- name: monthly
-- Sales volume and median €/m² per month, with a 3-month rolling median of the monthly medians.
WITH m AS (
    SELECT date_trunc('month', sold_on) AS month, count(*) AS sales, median(price_m2) AS median_m2
    FROM apartment_sales
    GROUP BY month
)
SELECT month, sales, round(median_m2, 0) AS median_eur_m2,
       round(avg(median_m2) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0) AS median_m2_3m_avg
FROM m
ORDER BY month;

-- name: top_streets
-- The most expensive streets (at least 15 sales over 2023-2024).
SELECT street, any_value(arrondissement) AS arrondissement, count(*) AS sales,
       round(median(price_m2), 0) AS median_eur_m2
FROM apartment_sales
GROUP BY street
HAVING count(*) >= 15
ORDER BY median_eur_m2 DESC
LIMIT 10;
