-- name: profile
-- How many listings are really active? (priced = bookable calendar; reviewed in the last 12 months)
SELECT count(*)                                                        AS listings,
       count(*) FILTER (WHERE price_per_night IS NOT NULL)             AS priced,
       count(*) FILTER (WHERE reviews_last_12m > 0)                    AS reviewed_last_12m,
       round(100.0 * count(*) FILTER (WHERE reviews_last_12m > 0) / count(*), 1) AS active_pct,
       count(DISTINCT host_id)                                         AS hosts,
       min(last_scraped)                                               AS scraped_from,
       max(last_scraped)                                               AS scraped_to
FROM listings;

-- name: room_types
SELECT room_type,
       count(*)                                                AS listings,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1)      AS share_pct,
       round(median(price_per_night), 0)                       AS median_price
FROM listings
GROUP BY room_type
ORDER BY listings DESC;

-- name: price_by_arrondissement
-- Median nightly price of entire homes per arrondissement (active, priced listings; price capped at 2,000 to drop junk).
SELECT a.arrondissement, a.neighbourhood,
       count(*)                                       AS listings,
       round(median(l.price_per_night), 0)            AS median_price,
       round(median(l.price_per_night / l.accommodates), 0) AS median_price_per_guest,
       round(avg(l.rating), 2)                         AS avg_rating
FROM listings l
JOIN arrondissements a USING (arrondissement)
WHERE l.room_type = 'Entire home/apt' AND l.price_per_night BETWEEN 10 AND 2000 AND l.reviews_last_12m > 0
GROUP BY ALL
ORDER BY median_price DESC;

-- name: host_concentration
-- Is Paris Airbnb run by residents or by professionals? Hosts grouped by portfolio size.
WITH hosts AS (
    SELECT host_id, count(*) AS n FROM listings GROUP BY host_id
)
SELECT CASE WHEN n = 1 THEN '1 listing' WHEN n <= 5 THEN '2-5 listings'
            WHEN n <= 20 THEN '6-20 listings' ELSE '21+ listings' END     AS portfolio,
       count(*)                                                            AS hosts,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1)                  AS hosts_pct,
       sum(n)                                                              AS listings,
       round(100.0 * sum(n) / sum(sum(n)) OVER (), 1)                      AS listings_pct
FROM hosts
GROUP BY portfolio
ORDER BY min(n);

-- name: top_hosts
SELECT host_id, any_value(host_name) AS host_name, count(*) AS listings,
       round(median(price_per_night), 0) AS median_price
FROM listings
GROUP BY host_id
ORDER BY listings DESC
LIMIT 10;

-- name: license_compliance
-- Registration numbers: missing, exempt, fake or reused.
SELECT license_status,
       count(*)                                              AS listings,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1)    AS pct
FROM license_check
WHERE room_type = 'Entire home/apt'
GROUP BY license_status
ORDER BY license_status;

-- name: occupancy
-- Inside Airbnb's estimated nights booked and revenue over 12 months, active listings only.
SELECT room_type,
       count(*)                                          AS listings,
       round(median(est_nights_booked_12m), 0)          AS median_nights_booked,
       round(median(est_revenue_12m), 0)                AS median_revenue,
       round(quantile_cont(est_revenue_12m, 0.9), 0)    AS p90_revenue
FROM listings
WHERE reviews_last_12m > 0
GROUP BY room_type
ORDER BY listings DESC;
