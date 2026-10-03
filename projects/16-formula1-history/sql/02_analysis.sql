-- name: coverage
SELECT (SELECT count(*) FROM races)                                   AS races_in_calendar,
       (SELECT count(*) FROM completed_races)                         AS races_with_results,
       (SELECT max(date) FROM completed_races)                        AS last_result_date,
       (SELECT count(*) FROM races WHERE race_id NOT IN (SELECT race_id FROM completed_races)) AS future_races,
       (SELECT count(*) FROM results)                                 AS result_rows,
       (SELECT count(DISTINCT driver_id) FROM results)                AS drivers;

-- name: top_winners
-- Most race wins, with win rate per start (drivers with 50+ starts).
WITH starts AS (
    SELECT driver_id, count(*) AS starts FROM results GROUP BY driver_id
)
SELECT d.name, c.country,
       count(w.race_id)                                     AS wins,
       s.starts,
       round(100.0 * count(w.race_id) / s.starts, 1)        AS win_rate_pct,
       (SELECT count(*) FROM champions ch WHERE ch.driver_id = d.driver_id) AS titles
FROM wins w
JOIN drivers d USING (driver_id)
JOIN starts s USING (driver_id)
LEFT JOIN countries c USING (country_id)
GROUP BY d.name, c.country, s.starts, d.driver_id
HAVING s.starts >= 50
ORDER BY wins DESC
LIMIT 12;

-- name: grid_to_win
-- How often does each starting position win? (all completed races, grid known)
SELECT grid_position,
       count(*) FILTER (WHERE finish_position = 1)                                       AS wins,
       round(100.0 * count(*) FILTER (WHERE finish_position = 1)
             / (SELECT count(*) FROM wins WHERE grid_position IS NOT NULL), 1)            AS share_of_all_wins_pct
FROM results
WHERE grid_position BETWEEN 1 AND 10
GROUP BY grid_position
ORDER BY grid_position;

-- name: pole_conversion
-- Share of races won from pole position, by decade.
SELECT (year // 10) * 10                                               AS decade,
       count(*)                                                        AS races,
       round(100.0 * count(*) FILTER (WHERE grid_position = 1) / count(*), 1) AS won_from_pole_pct
FROM wins
GROUP BY decade
ORDER BY decade;

-- name: reliability
-- Finishing rate by decade: share of starters classified at the finish.
SELECT (year // 10) * 10                                                   AS decade,
       count(*)                                                            AS starts,
       round(100.0 * count(*) FILTER (WHERE finish_position IS NOT NULL) / count(*), 1) AS finished_pct
FROM results
GROUP BY decade
ORDER BY decade;

-- name: dominant_seasons
-- The most dominant single seasons: share of the season's races won by one driver (complete seasons only).
WITH per_season AS (
    SELECT w.year, w.driver_id, count(*) AS wins,
           (SELECT count(*) FROM completed_races r WHERE r.year = w.year) AS races
    FROM wins w
    WHERE w.year < (SELECT max(year) FROM completed_races)
    GROUP BY w.year, w.driver_id
)
SELECT p.year, d.name, p.wins, p.races, round(100.0 * p.wins / p.races, 1) AS win_share_pct
FROM per_season p JOIN drivers d USING (driver_id)
ORDER BY win_share_pct DESC, wins DESC
LIMIT 10;

-- name: constructor_eras
-- The winningest constructor of each decade and its share of that decade's wins.
WITH c AS (
    SELECT (year // 10) * 10 AS decade, constructor_id, count(*) AS wins,
           sum(count(*)) OVER (PARTITION BY (year // 10) * 10) AS decade_wins
    FROM wins
    GROUP BY decade, constructor_id
)
SELECT decade, k.name AS constructor, wins, round(100.0 * wins / decade_wins, 1) AS share_pct
FROM c JOIN constructors k USING (constructor_id)
QUALIFY row_number() OVER (PARTITION BY decade ORDER BY wins DESC) = 1
ORDER BY decade;

-- name: titles_by_country
-- World champions' titles by nationality.
SELECT c.country, count(*) AS titles, count(DISTINCT ch.driver_id) AS champions
FROM champions ch
JOIN drivers d USING (driver_id)
JOIN countries c USING (country_id)
GROUP BY c.country
ORDER BY titles DESC
LIMIT 10;
