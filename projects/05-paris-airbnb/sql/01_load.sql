-- Inside Airbnb, Paris snapshot of June 2026: one row per listing.

CREATE OR REPLACE TABLE arrondissements AS
SELECT * FROM (VALUES
    (1, 'Louvre'), (2, 'Bourse'), (3, 'Temple'), (4, 'Hôtel-de-Ville'), (5, 'Panthéon'),
    (6, 'Luxembourg'), (7, 'Palais-Bourbon'), (8, 'Élysée'), (9, 'Opéra'), (10, 'Entrepôt'),
    (11, 'Popincourt'), (12, 'Reuilly'), (13, 'Gobelins'), (14, 'Observatoire'), (15, 'Vaugirard'),
    (16, 'Passy'), (17, 'Batignolles-Monceau'), (18, 'Buttes-Montmartre'), (19, 'Buttes-Chaumont'), (20, 'Ménilmontant')
) AS t(arrondissement, neighbourhood);

CREATE OR REPLACE TABLE listings AS
SELECT
    l.id                                                            AS listing_id,
    l.host_id,
    l.host_name,
    l.host_is_superhost = 't'                                      AS is_superhost,
    a.arrondissement,
    l.room_type,
    l.accommodates,
    l.bedrooms,
    CAST(replace(replace(l.price, '$', ''), ',', '') AS DOUBLE)    AS price_per_night,
    l.minimum_nights,
    l.availability_365,
    l.number_of_reviews,
    l.number_of_reviews_ltm                                         AS reviews_last_12m,
    l.review_scores_rating                                          AS rating,
    l.estimated_occupancy_l365d                                     AS est_nights_booked_12m,
    l.estimated_revenue_l365d                                       AS est_revenue_12m,
    l.calculated_host_listings_count                                AS host_listings,
    l.license,
    l.last_scraped
FROM read_csv_auto('data/listings.csv.gz') l
LEFT JOIN arrondissements a ON a.neighbourhood = l.neighbourhood_cleansed;

-- Paris requires a 13-digit registration number (75 + 11 digits) for short-term rentals of homes.
CREATE OR REPLACE TABLE license_check AS
WITH usage AS (
    SELECT license, count(DISTINCT host_id) AS hosts_using_it
    FROM listings
    WHERE regexp_matches(license, '^75[0-9]{11}$')
    GROUP BY license
)
SELECT l.listing_id, l.room_type, l.license,
       CASE
           WHEN l.license IS NULL                                   THEN '1. No license number'
           WHEN l.license ILIKE 'Available with a mobility lease%'  THEN '2. Mobility lease (exempt)'
           WHEN l.license ILIKE 'Exempt%'                           THEN '3. Hotel-type (exempt)'
           WHEN regexp_matches(l.license, '^7512345678')            THEN '4. Obvious placeholder (75123456789x)'
           WHEN NOT regexp_matches(l.license, '^75[0-9]{11}$')      THEN '5. Malformed number'
           WHEN u.hosts_using_it > 1                                THEN '6. Same number used by several hosts'
           ELSE                                                          '7. Well-formed, unique number'
       END AS license_status
FROM listings l
LEFT JOIN usage u USING (license);
