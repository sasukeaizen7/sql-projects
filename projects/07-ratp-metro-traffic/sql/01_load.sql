-- RATP annual entries per Métro / RER station, one file per year (2013-2021), stacked into one table.

CREATE OR REPLACE TABLE traffic AS
SELECT
    CAST(regexp_extract(filename, '(\d{4})\.csv$', 1) AS INTEGER)       AS year,
    reseau                                                              AS network,
    rtrim(station, '*')                                                 AS station,   -- 2013 marks one station with '**'
    CAST(trafic AS BIGINT)                                              AS entries,
    ville                                                               AS city,
    TRY_CAST(arrondissement_pour_paris AS INTEGER)                      AS arrondissement,
    -- number of lines served = non-empty correspondance_* columns
    (correspondance_1 IS NOT NULL)::INT + (correspondance_2 IS NOT NULL)::INT + (correspondance_3 IS NOT NULL)::INT
      + (correspondance_4 IS NOT NULL)::INT + (correspondance_5 IS NOT NULL)::INT AS lines_served
FROM read_csv('data/ratp_traffic_*.csv', delim = ';', header = true, filename = true,
              union_by_name = true, all_varchar = true);
