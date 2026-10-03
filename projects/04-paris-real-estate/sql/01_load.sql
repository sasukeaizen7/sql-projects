-- DVF (Demandes de valeurs foncières): every property sale registered in Paris, 2023-2024.
-- One sale (id_mutation) spans several rows: one per building lot (apartment, cellar, parking...).

CREATE OR REPLACE TABLE dvf_raw AS
SELECT * FROM read_csv(['data/dvf_2023_paris.csv.gz', 'data/dvf_2024_paris.csv.gz'], header = true, all_varchar = true, union_by_name = true);  -- typed explicitly below

-- One row per sale, with what it contains.
CREATE OR REPLACE TABLE sales_summary AS
SELECT
    id_mutation,
    any_value(CAST(date_mutation AS DATE))                         AS sold_on,
    any_value(nature_mutation)                                     AS nature,
    any_value(CAST(valeur_fonciere AS DOUBLE))                     AS price_eur,
    any_value(CAST(code_commune AS INTEGER) - 75100)               AS arrondissement,
    any_value(adresse_nom_voie)                                    AS street,
    count(*) FILTER (WHERE type_local = 'Appartement')             AS apartments,
    count(*) FILTER (WHERE type_local IN ('Maison', 'Local industriel. commercial ou assimilé')) AS other_buildings,
    sum(CAST(surface_reelle_bati AS DOUBLE)) FILTER (WHERE type_local = 'Appartement') AS living_m2,
    any_value(CAST(nombre_pieces_principales AS INTEGER)) FILTER (WHERE type_local = 'Appartement') AS rooms
FROM dvf_raw
GROUP BY id_mutation;

-- Keep standard apartment sales: one apartment (cellars/parking allowed), plausible size and price.
CREATE OR REPLACE TABLE sale_quality AS
SELECT *,
       price_eur / nullif(living_m2, 0) AS price_m2,
       CASE
           WHEN nature <> 'Vente'                         THEN 'not a standard sale (exchange, off-plan...)'
           WHEN apartments = 0                            THEN 'no apartment (parking, shop, land...)'
           WHEN apartments > 1 OR other_buildings > 0     THEN 'bulk sale (several apartments or mixed)'
           WHEN price_eur IS NULL OR living_m2 IS NULL    THEN 'missing price or surface'
           WHEN living_m2 < 9 OR living_m2 > 300          THEN 'surface outside 9-300 m²'
           WHEN price_eur / living_m2 NOT BETWEEN 3000 AND 40000 THEN 'price/m² outside 3k-40k €'
           ELSE 'ok'
       END AS quality
FROM sales_summary;

CREATE OR REPLACE TABLE apartment_sales AS
SELECT id_mutation, sold_on, year(sold_on) AS year, arrondissement, street, price_eur, living_m2, rooms, price_m2
FROM sale_quality
WHERE quality = 'ok';
