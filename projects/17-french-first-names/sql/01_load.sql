-- INSEE "Fichier des prénoms": first names given to babies born in France, 1900-2024,
-- at national, regional and departmental level. Counts are rounded to a multiple of 5 (privacy).

CREATE OR REPLACE TABLE names_raw AS
SELECT * FROM read_parquet('data/prenoms-2024.parquet');

CREATE OR REPLACE TABLE regions AS
SELECT * FROM (VALUES
    ('11', 'Île-de-France'), ('24', 'Centre-Val de Loire'), ('27', 'Bourgogne-Franche-Comté'), ('28', 'Normandie'),
    ('32', 'Hauts-de-France'), ('44', 'Grand Est'), ('52', 'Pays de la Loire'), ('53', 'Bretagne'),
    ('75', 'Nouvelle-Aquitaine'), ('76', 'Occitanie'), ('84', 'Auvergne-Rhône-Alpes'), ('93', 'Provence-Alpes-Côte d''Azur'),
    ('94', 'Corse'), ('01', 'Guadeloupe'), ('02', 'Martinique'), ('03', 'Guyane'), ('04', 'La Réunion'), ('06', 'Mayotte')
) AS t(region_code, region);

-- National level, typed, with readable sex labels. 'RARES' groups names given too rarely to publish.
CREATE OR REPLACE TABLE births AS
SELECT CAST(periode AS INTEGER) AS year,
       CASE sexe WHEN '1' THEN 'boy' WHEN '2' THEN 'girl' END AS sex,
       initcap_name AS name,
       valeur AS babies
FROM (
    SELECT *, upper(prenom[1]) || lower(prenom[2:]) AS initcap_name
    FROM names_raw
    WHERE niveau_geographique = 'FRANCE' AND prenom <> 'RARES'
);

CREATE OR REPLACE TABLE births_by_region AS
SELECT CAST(n.periode AS INTEGER) AS year,
       CASE n.sexe WHEN '1' THEN 'boy' WHEN '2' THEN 'girl' END AS sex,
       upper(n.prenom[1]) || lower(n.prenom[2:]) AS name,
       r.region, n.valeur AS babies
FROM names_raw n
JOIN regions r ON r.region_code = n.geographie
WHERE n.niveau_geographique = 'REG' AND n.prenom <> 'RARES';
