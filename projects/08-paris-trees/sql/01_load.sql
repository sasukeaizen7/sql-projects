-- Les arbres de Paris: every tree managed by the City (streets, parks, cemeteries, schools...).

CREATE OR REPLACE TABLE trees_raw AS
SELECT * FROM read_csv('data/paris_trees.csv', delim = ';', header = true);

CREATE OR REPLACE TABLE trees AS
SELECT
    idbase                                                         AS tree_id,
    domanialite                                                    AS site_type,          -- street, garden, cemetery...
    arrondissement                                                 AS area_raw,
    CASE WHEN area_raw LIKE 'PARIS %ARRDT' THEN CAST(regexp_extract(area_raw, 'PARIS (\d+)', 1) AS INTEGER) END AS arrondissement,
    CASE WHEN area_raw LIKE 'PARIS %ARRDT' THEN 'Paris'
         WHEN area_raw LIKE 'BOIS%'          THEN 'Woods (Boulogne / Vincennes)'
         ELSE 'Outside Paris (city-owned sites)' END              AS zone,
    nullif(trim(libellefrancais), '')                              AS species_fr,
    nullif(trim(genre), '')                                        AS genus,
    nullif(trim(espece), '')                                       AS species,
    -- 0 means "not measured": turn it into NULL; drop physically impossible values.
    CASE WHEN hauteurenm BETWEEN 1 AND 45 THEN hauteurenm END      AS height_m,
    CASE WHEN circonferenceencm BETWEEN 5 AND 700 THEN circonferenceencm END AS circumference_cm,
    CASE stadedeveloppement WHEN 'Jeune (arbre)Adulte' THEN 'Young adult' WHEN 'Jeune (arbre)' THEN 'Young'
                            WHEN 'Adulte' THEN 'Adult' WHEN 'Mature' THEN 'Mature' END AS stage,
    remarquable = 'OUI'                                            AS is_remarkable,
    hauteurenm                                                     AS height_raw,
    circonferenceencm                                              AS circumference_raw
FROM trees_raw;
