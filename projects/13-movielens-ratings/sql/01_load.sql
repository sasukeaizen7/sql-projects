-- MovieLens "latest-small" (GroupLens): 100k ratings by 610 users on 9.7k movies.

CREATE OR REPLACE TABLE movies AS
SELECT movieId AS movie_id,
       title,
       TRY_CAST(regexp_extract(title, '\((\d{4})\)\s*$', 1) AS INTEGER) AS release_year,
       genres
FROM read_csv('data/ml-latest-small/movies.csv', header = true);

-- One row per (movie, genre): genres are stored as a pipe-separated list.
CREATE OR REPLACE TABLE movie_genres AS
SELECT movie_id, unnest(string_split(genres, '|')) AS genre
FROM movies
WHERE genres <> '(no genres listed)';

CREATE OR REPLACE TABLE ratings AS
SELECT userId AS user_id, movieId AS movie_id, rating, to_timestamp(timestamp) AS rated_at
FROM read_csv('data/ml-latest-small/ratings.csv', header = true);

CREATE OR REPLACE TABLE tags AS
SELECT userId AS user_id, movieId AS movie_id, lower(trim(tag)) AS tag, to_timestamp(timestamp) AS tagged_at
FROM read_csv('data/ml-latest-small/tags.csv', header = true);
