-- name: profile
-- Size, sparsity and time span of the rating matrix.
SELECT count(*)                                                      AS ratings,
       count(DISTINCT user_id)                                       AS users,
       count(DISTINCT movie_id)                                      AS rated_movies,
       (SELECT count(*) FROM movies)                                 AS catalog_movies,
       round(100.0 * count(*) / (count(DISTINCT user_id) * count(DISTINCT movie_id)), 2) AS matrix_fill_pct,
       round(avg(rating), 2)                                         AS avg_rating,
       min(rated_at)::DATE                                           AS first_rating,
       max(rated_at)::DATE                                           AS last_rating
FROM ratings;

-- name: rating_distribution
SELECT rating, count(*) AS ratings, round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
FROM ratings
GROUP BY rating
ORDER BY rating;

-- name: naive_top
-- Why a plain average is a bad ranking: the "best" movies have one or two ratings.
SELECT m.title, count(*) AS ratings, round(avg(r.rating), 2) AS avg_rating
FROM ratings r JOIN movies m USING (movie_id)
GROUP BY m.title
ORDER BY avg_rating DESC, ratings DESC
LIMIT 10;

-- name: weighted_top
-- IMDb-style weighted rating: (v/(v+m))*R + (m/(v+m))*C, with m = 50 votes and C = global mean.
WITH stats AS (
    SELECT movie_id, count(*) AS v, avg(rating) AS r FROM ratings GROUP BY movie_id
), params AS (
    SELECT 50 AS m, (SELECT avg(rating) FROM ratings) AS c
)
SELECT mv.title, s.v AS ratings, round(s.r, 2) AS avg_rating,
       round((s.v / (s.v + p.m)) * s.r + (p.m / (s.v + p.m)) * p.c, 3) AS weighted_rating
FROM stats s CROSS JOIN params p JOIN movies mv USING (movie_id)
ORDER BY weighted_rating DESC
LIMIT 15;

-- name: genres
-- Popularity vs appreciation by genre (a movie counts in each of its genres).
SELECT g.genre,
       count(DISTINCT g.movie_id)                     AS movies,
       count(*)                                       AS ratings,
       round(avg(r.rating), 2)                        AS avg_rating
FROM movie_genres g
JOIN ratings r USING (movie_id)
GROUP BY g.genre
ORDER BY ratings DESC;

-- name: by_decade
-- Do older movies get better ratings? (survivorship: only classics are still watched)
SELECT (release_year // 10) * 10                     AS decade,
       count(DISTINCT movie_id)                       AS movies,
       count(*)                                       AS ratings,
       round(avg(rating), 2)                          AS avg_rating
FROM ratings JOIN movies USING (movie_id)
WHERE release_year IS NOT NULL AND release_year >= 1920
GROUP BY decade
ORDER BY decade;

-- name: user_activity
-- Long tail of users: share of all ratings given by the most active 10% (NTILE).
WITH u AS (
    SELECT user_id, count(*) AS n FROM ratings GROUP BY user_id
), d AS (
    SELECT *, ntile(10) OVER (ORDER BY n DESC) AS decile FROM u
)
SELECT decile, count(*) AS users, sum(n) AS ratings,
       round(100.0 * sum(n) / sum(sum(n)) OVER (), 1) AS share_pct,
       min(n) AS min_ratings_per_user, max(n) AS max_ratings_per_user
FROM d
GROUP BY decile
ORDER BY decile;

-- name: top_tags
SELECT tag, count(*) AS uses, count(DISTINCT movie_id) AS movies
FROM tags
GROUP BY tag
ORDER BY uses DESC
LIMIT 10;
