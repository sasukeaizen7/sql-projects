-- name: profile
SELECT niveau_geographique AS level, count(*) AS rows, count(DISTINCT geographie) AS areas,
       min(periode) AS first_year, max(periode) AS last_year,
       round(100.0 * avg((valeur % 5 = 0)::INT), 1) AS pct_rounded_to_5
FROM names_raw
GROUP BY level
ORDER BY rows DESC;

-- name: top_2024
-- Most given names in 2024, by sex (top 10 each, RANK per partition).
SELECT sex, name, babies, rank() OVER (PARTITION BY sex ORDER BY babies DESC) AS rnk
FROM births
WHERE year = 2024
QUALIFY rnk <= 10
ORDER BY sex, rnk;

-- name: all_time
-- Most given names since 1900, by sex.
SELECT sex, name, sum(babies) AS babies, rank() OVER (PARTITION BY sex ORDER BY sum(babies) DESC) AS rnk,
       arg_max(year, babies) AS peak_year
FROM births
GROUP BY sex, name
QUALIFY rnk <= 5
ORDER BY sex, rnk;

-- name: concentration
-- Name diversity over time: share of babies given one of the year's 10 most common names, and distinct names.
WITH ranked AS (
    SELECT year, sex, babies, row_number() OVER (PARTITION BY year, sex ORDER BY babies DESC) AS rn
    FROM births
)
SELECT year,
       round(100.0 * sum(babies) FILTER (WHERE rn <= 10) / sum(babies), 1) AS top10_share_pct,
       count(*)                                                           AS distinct_names
FROM ranked
GROUP BY year
ORDER BY year;

-- name: rise_and_fall
-- Popularity curves of iconic names (babies per year).
SELECT year, name, sum(babies) AS babies
FROM births
WHERE (name, sex) IN (('Marie', 'girl'), ('Jean', 'boy'), ('Kevin', 'boy'), ('Nathalie', 'girl'), ('Gabriel', 'boy'))
GROUP BY year, name
ORDER BY name, year;

-- name: peaks
-- When was each name at its peak? (ARG_MAX), for the 25 most given names since 1950.
WITH totals AS (
    SELECT name, sex, sum(babies) AS babies FROM births WHERE year >= 1950 GROUP BY name, sex
    ORDER BY babies DESC LIMIT 25
)
SELECT b.name, b.sex, t.babies AS babies_since_1950, arg_max(b.year, b.babies) AS peak_year, max(b.babies) AS peak_babies
FROM births b JOIN totals t USING (name, sex)
GROUP BY b.name, b.sex, t.babies
ORDER BY peak_year;

-- name: risers
-- Fastest-growing names over the last decade (2014 -> 2024, at least 500 babies in 2024).
SELECT name, sex,
       sum(babies) FILTER (WHERE year = 2014) AS babies_2014,
       sum(babies) FILTER (WHERE year = 2024) AS babies_2024,
       round(sum(babies) FILTER (WHERE year = 2024)::DOUBLE / sum(babies) FILTER (WHERE year = 2014), 1) AS growth_x
FROM births
GROUP BY name, sex
HAVING babies_2024 >= 500 AND babies_2014 > 0
ORDER BY growth_x DESC
LIMIT 10;

-- name: top_by_region
-- The number-one boy's and girl's name in each region in 2024.
SELECT region, sex, name, babies
FROM births_by_region
WHERE year = 2024
QUALIFY row_number() OVER (PARTITION BY region, sex ORDER BY babies DESC, name) = 1
ORDER BY region, sex;
