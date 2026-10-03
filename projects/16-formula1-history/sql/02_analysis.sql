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
ORDER BY wins DESC, win_rate_pct DESC, d.name
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
ORDER BY win_share_pct DESC, wins DESC, p.year
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
ORDER BY titles DESC, champions DESC, c.country
LIMIT 10;

-- ============================================================================================
-- Advanced SQL
-- ============================================================================================

-- name: win_streaks
-- Longest runs of consecutive race wins (gaps and islands). Each driver's starts are numbered in date
-- order; within a winning streak, (start number - win number) stays constant.
WITH starts AS (
    SELECT res.driver_id, r.date, res.race_id, res.finish_position = 1 AS won,
           row_number() OVER (PARTITION BY res.driver_id ORDER BY r.date, res.race_id) AS start_no
    FROM results res
    JOIN races r USING (race_id)
    QUALIFY row_number() OVER (PARTITION BY res.driver_id, res.race_id ORDER BY res.position_order) = 1  -- shared cars: one start
), streaks AS (
    SELECT driver_id, date, start_no - row_number() OVER (PARTITION BY driver_id ORDER BY start_no) AS island
    FROM starts
    WHERE won
)
SELECT d.name, count(*) AS consecutive_wins, min(s.date) AS first_win, max(s.date) AS last_win
FROM streaks s JOIN drivers d USING (driver_id)
GROUP BY d.name, s.driver_id, s.island
ORDER BY consecutive_wins DESC, first_win
LIMIT 10;

-- name: teammate_battles
-- Head-to-head against team-mates: a self-join of results on (race, constructor). Counts races where
-- both cars were classified; most lopsided pairings with 30+ such races.
WITH pairs AS (
    SELECT a.driver_id AS driver, b.driver_id AS teammate,
           count(*)                                                    AS races_together,
           count(*) FILTER (WHERE a.finish_position < b.finish_position) AS ahead
    FROM results a
    JOIN results b ON b.race_id = a.race_id AND b.constructor_id = a.constructor_id AND b.driver_id <> a.driver_id
    WHERE a.finish_position IS NOT NULL AND b.finish_position IS NOT NULL
      AND NOT coalesce(a.shared_car, false) AND NOT coalesce(b.shared_car, false)
    GROUP BY ALL
)
SELECT d.name AS driver, t.name AS teammate, races_together, ahead,
       races_together - ahead                                  AS behind,
       round(100.0 * ahead / races_together, 1)                AS ahead_pct
FROM pairs p
JOIN drivers d ON d.driver_id = p.driver
JOIN drivers t ON t.driver_id = p.teammate
WHERE races_together >= 30
ORDER BY ahead_pct DESC, races_together DESC
LIMIT 10;

-- name: closest_titles
-- The closest championship fights: champion vs runner-up in the final standings (lead() over the table).
WITH standings AS (
    SELECT s.year, s.position, d.name, s.points,
           lead(d.name)   OVER w AS runner_up,
           lead(s.points) OVER w AS runner_up_points
    FROM season_standings s JOIN drivers d USING (driver_id)
    WINDOW w AS (PARTITION BY s.year ORDER BY s.position)
)
SELECT year, name AS champion, points, runner_up, runner_up_points,
       points - runner_up_points AS margin
FROM standings
WHERE position = 1 AND year < (SELECT max(year) FROM completed_races)
ORDER BY margin, year
LIMIT 10;

-- name: champion_best_season
-- Every multiple world champion's best season by wins: a LATERAL subquery returns each driver's top year.
SELECT d.name, ch.titles, b.year AS best_year, b.wins, b.races, round(100.0 * b.wins / b.races, 1) AS win_pct
FROM (SELECT driver_id, count(*) AS titles FROM champions GROUP BY driver_id HAVING count(*) >= 2) ch
JOIN drivers d USING (driver_id),
LATERAL (
    SELECT w.year, count(*) AS wins,
           (SELECT count(*) FROM completed_races r WHERE r.year = w.year) AS races
    FROM wins w
    WHERE w.driver_id = ch.driver_id
    GROUP BY w.year
    ORDER BY wins DESC, w.year
    LIMIT 1
) b
ORDER BY ch.titles DESC, b.wins DESC, d.name;
