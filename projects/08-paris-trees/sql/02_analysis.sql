-- name: data_quality
-- How reliable are the measurements?
SELECT count(*)                                                          AS trees,
       count(*) FILTER (WHERE height_raw = 0)                            AS height_zero,
       count(*) FILTER (WHERE height_raw > 45)                           AS height_over_45m,
       max(height_raw)                                                   AS max_height_raw,
       count(*) FILTER (WHERE circumference_raw = 0)                     AS circumference_zero,
       count(*) FILTER (WHERE circumference_raw > 700)                   AS circumference_over_7m,
       count(*) FILTER (WHERE species_fr IS NULL)                        AS species_missing,
       count(*) FILTER (WHERE stage IS NULL)                             AS stage_missing,
       count(*) FILTER (WHERE height_m IS NOT NULL AND circumference_cm IS NOT NULL) AS fully_measured
FROM trees;

-- name: zones
SELECT zone, count(*) AS trees, round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
FROM trees GROUP BY zone ORDER BY trees DESC;

-- name: site_types
SELECT site_type, count(*) AS trees, round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
FROM trees GROUP BY site_type ORDER BY trees DESC;

-- name: top_species
-- The 10 most common trees.
SELECT species_fr, any_value(genus) AS genus, count(*) AS trees,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
FROM trees
WHERE species_fr IS NOT NULL
GROUP BY species_fr
ORDER BY trees DESC
LIMIT 10;

-- name: street_monoculture
-- Street trees only: how dependent is each arrondissement on its single most common genus?
WITH counts AS (
    SELECT arrondissement, genus, count(*) AS n
    FROM trees
    WHERE site_type = 'Alignement' AND arrondissement IS NOT NULL AND genus IS NOT NULL
    GROUP BY ALL
), ranked AS (
    SELECT *, row_number() OVER (PARTITION BY arrondissement ORDER BY n DESC) AS rn,
              sum(n) OVER (PARTITION BY arrondissement) AS total,
              count(*) OVER (PARTITION BY arrondissement) AS genera
    FROM counts
)
SELECT arrondissement, total AS street_trees, genera, genus AS top_genus,
       round(100.0 * n / total, 1) AS top_genus_pct
FROM ranked
WHERE rn = 1
ORDER BY top_genus_pct DESC;

-- name: height_by_genus
-- Median height and trunk circumference for the 10 most common genera (measured trees only).
SELECT genus,
       count(*)                              AS measured_trees,
       round(median(height_m), 1)            AS median_height_m,
       round(quantile_cont(height_m, 0.9), 1) AS p90_height_m,
       round(median(circumference_cm), 0)    AS median_circumference_cm
FROM trees
WHERE genus IS NOT NULL AND height_m IS NOT NULL AND circumference_cm IS NOT NULL
GROUP BY genus
ORDER BY count(*) DESC
LIMIT 10;

-- name: remarkable
-- Officially "remarkable" trees: which species, and how big?
SELECT species_fr, count(*) AS trees, round(median(height_m), 0) AS median_height_m,
       max(circumference_cm) AS max_circumference_cm
FROM trees
WHERE is_remarkable
GROUP BY species_fr
ORDER BY trees DESC
LIMIT 10;

-- name: stages
-- Age structure: young vs mature trees, by site type.
SELECT site_type,
       count(*) FILTER (WHERE stage IS NOT NULL)                                              AS staged_trees,
       round(100.0 * count(*) FILTER (WHERE stage IN ('Young', 'Young adult')) / count(*) FILTER (WHERE stage IS NOT NULL), 1) AS young_pct,
       round(100.0 * count(*) FILTER (WHERE stage = 'Mature') / count(*) FILTER (WHERE stage IS NOT NULL), 1)                 AS mature_pct
FROM trees
WHERE site_type IN ('Alignement', 'Jardin', 'CIMETIERE', 'PERIPHERIQUE')
GROUP BY site_type
ORDER BY staged_trees DESC;
