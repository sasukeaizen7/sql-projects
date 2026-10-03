-- name: integrity_checks
-- Do invoice totals match their lines, and is every line linked to a real track?
SELECT
    (SELECT count(*) FROM invoice)                                                    AS invoices,
    (SELECT count(*) FROM invoice i
       JOIN (SELECT invoice_id, sum(unit_price * quantity) AS lines_total FROM invoice_line GROUP BY 1) l
         USING (invoice_id)
      WHERE abs(i.total - l.lines_total) > 0.005)                                     AS invoices_total_mismatch,
    (SELECT count(*) FROM invoice_line il LEFT JOIN track t USING (track_id) WHERE t.track_id IS NULL) AS orphan_lines,
    (SELECT min(invoice_date) FROM invoice)                                           AS first_invoice,
    (SELECT max(invoice_date) FROM invoice)                                           AS last_invoice;

-- name: revenue_by_country
-- Which countries generate the most revenue, per customer and in total?
SELECT c.country,
       count(DISTINCT c.customer_id)                                       AS customers,
       round(sum(i.total), 2)                                             AS revenue,
       round(sum(i.total) / count(DISTINCT c.customer_id), 2)             AS revenue_per_customer,
       round(100.0 * sum(i.total) / sum(sum(i.total)) OVER (), 1)         AS share_pct
FROM customer c
JOIN invoice i USING (customer_id)
GROUP BY c.country
ORDER BY revenue DESC
LIMIT 10;

-- name: revenue_by_genre
-- Which genres sell, and what share of track sales do they represent?
SELECT g.name                                                        AS genre,
       sum(il.quantity)                                              AS tracks_sold,
       round(sum(il.unit_price * il.quantity), 2)                    AS revenue,
       round(100.0 * sum(il.unit_price * il.quantity)
             / sum(sum(il.unit_price * il.quantity)) OVER (), 1)     AS share_pct
FROM invoice_line il
JOIN track t USING (track_id)
JOIN genre g USING (genre_id)
GROUP BY g.name
ORDER BY revenue DESC
LIMIT 10;

-- name: yearly_revenue
-- Revenue per year with year-over-year growth (LAG).
SELECT year(invoice_date)                                                       AS year,
       count(*)                                                                 AS invoices,
       round(sum(total), 2)                                                     AS revenue,
       round(100.0 * (sum(total) - lag(sum(total)) OVER (ORDER BY year(invoice_date)))
             / lag(sum(total)) OVER (ORDER BY year(invoice_date)), 1)          AS yoy_growth_pct
FROM invoice
GROUP BY year
ORDER BY year;

-- name: monthly_revenue
-- Monthly revenue and a 3-month rolling average.
SELECT date_trunc('month', invoice_date)                                         AS month,
       round(sum(total), 2)                                                      AS revenue,
       round(avg(sum(total)) OVER (ORDER BY date_trunc('month', invoice_date)
                                   ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS revenue_3m_avg
FROM invoice
GROUP BY month
ORDER BY month;

-- name: sales_reps
-- How do support reps compare (customers, revenue, rank)?
SELECT e.name                                               AS sales_rep,
       e.hire_date,
       count(DISTINCT c.customer_id)                        AS customers,
       round(sum(i.total), 2)                               AS revenue,
       rank() OVER (ORDER BY sum(i.total) DESC)             AS revenue_rank
FROM employee e
JOIN customer c ON c.support_rep_id = e.employee_id
JOIN invoice i USING (customer_id)
GROUP BY e.name, e.hire_date
ORDER BY revenue_rank;

-- name: customer_segments
-- How is customer lifetime value distributed? (Quartiles with ntile() would be meaningless: half the
-- customers have exactly the same value, and ntile() splits tied rows arbitrarily.)
WITH ltv AS (
    SELECT customer_id, sum(total) AS lifetime_value, count(*) AS orders
    FROM invoice
    GROUP BY customer_id
)
SELECT lifetime_value,
       count(*)                                                                AS customers,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1)                      AS pct,
       sum(count(*)) OVER (ORDER BY lifetime_value DESC)                       AS customers_at_or_above,
       round(avg(orders), 1)                                                   AS avg_orders
FROM ltv
GROUP BY lifetime_value
ORDER BY lifetime_value DESC;

-- name: top_artist_per_country
-- The best-selling artist in each of the top 8 markets (ROW_NUMBER per partition).
WITH sales AS (
    SELECT c.country, ar.name AS artist, sum(il.quantity) AS tracks_sold
    FROM invoice_line il
    JOIN invoice i USING (invoice_id)
    JOIN customer c USING (customer_id)
    JOIN track t USING (track_id)
    JOIN album al USING (album_id)
    JOIN artist ar USING (artist_id)
    GROUP BY c.country, ar.name
), ranked AS (
    SELECT *, row_number() OVER (PARTITION BY country ORDER BY tracks_sold DESC, artist) AS rn,
              sum(tracks_sold) OVER (PARTITION BY country) AS country_tracks
    FROM sales
)
SELECT country, artist, tracks_sold, country_tracks
FROM ranked
WHERE rn = 1
ORDER BY country_tracks DESC, country
LIMIT 8;

-- name: catalog_coverage
-- How much of the catalog never sold, by media type?
SELECT mt.name                                                            AS media_type,
       count(*)                                                           AS tracks,
       count(*) FILTER (WHERE s.track_id IS NULL)                         AS never_sold,
       round(100.0 * count(*) FILTER (WHERE s.track_id IS NULL) / count(*), 1) AS never_sold_pct
FROM track t
JOIN media_type mt USING (media_type_id)
LEFT JOIN (SELECT DISTINCT track_id FROM invoice_line) s USING (track_id)
GROUP BY mt.name
ORDER BY tracks DESC;

-- ============================================================================================
-- Advanced SQL
-- ============================================================================================

-- name: org_chart
-- The reporting hierarchy (recursive CTE over the self-referencing employee table), with each
-- person's path from the top and the revenue of every customer handled by them or anyone below them.
WITH RECURSIVE tree(employee_id, name, title, depth, path) AS (
    SELECT employee_id, name, title, 0, [name]
    FROM employee WHERE reports_to IS NULL
    UNION ALL
    SELECT e.employee_id, e.name, e.title, t.depth + 1, list_append(t.path, e.name)
    FROM employee e JOIN tree t ON e.reports_to = t.employee_id
), closure(manager_id, employee_id) AS (       -- every (manager, employee-below-or-self) pair
    SELECT employee_id, employee_id FROM employee
    UNION ALL
    SELECT c.manager_id, e.employee_id FROM closure c JOIN employee e ON e.reports_to = c.employee_id
), rep_revenue AS (
    SELECT c.support_rep_id AS employee_id, count(DISTINCT c.customer_id) AS customers, sum(i.total) AS revenue
    FROM customer c JOIN invoice i USING (customer_id)
    GROUP BY 1
)
SELECT repeat('    ', t.depth) || t.name                    AS employee,
       t.title,
       array_to_string(t.path, ' > ')                          AS reporting_line,
       coalesce(sum(r.customers), 0)                           AS customers_in_scope,
       coalesce(sum(r.revenue), 0)                             AS revenue_in_scope
FROM tree t
JOIN closure cl ON cl.manager_id = t.employee_id
LEFT JOIN rep_revenue r ON r.employee_id = cl.employee_id
GROUP BY t.employee_id, t.name, t.title, t.depth, t.path
ORDER BY array_to_string(t.path, ' > ');

-- name: full_album_purchases
-- Relational division: which invoices bought EVERY track of an album? (Albums of 2+ tracks: buying
-- the only track of a 1-track album is trivially a full album.)
-- An invoice "covers" an album when no track of that album is missing from it (double NOT EXISTS).
WITH albums AS (
    SELECT album_id, count(*) AS tracks FROM track GROUP BY album_id HAVING count(*) >= 2
), candidates AS (                 -- invoice/album pairs with at least one track bought
    SELECT DISTINCT il.invoice_id, t.album_id
    FROM invoice_line il JOIN track t USING (track_id)
    WHERE t.album_id IN (SELECT album_id FROM albums)
)
SELECT count(*)                                                                AS invoice_album_pairs,
       count(*) FILTER (WHERE NOT EXISTS (
           SELECT 1 FROM track t
           WHERE t.album_id = c.album_id
             AND NOT EXISTS (SELECT 1 FROM invoice_line il
                             WHERE il.invoice_id = c.invoice_id AND il.track_id = t.track_id))) AS full_album_purchases,
       (SELECT max(n) FROM (SELECT count(*) AS n FROM invoice_line GROUP BY invoice_id)) AS max_lines_per_invoice
FROM candidates c JOIN albums a USING (album_id);

-- name: playlist_similarity
-- Which playlists overlap? Jaccard similarity |A ∩ B| / |A ∪ B| from a self-join of the bridge table.
WITH sizes AS (
    SELECT playlist_id, count(*) AS tracks FROM playlist_track GROUP BY playlist_id
), shared AS (
    SELECT a.playlist_id AS a, b.playlist_id AS b, count(*) AS common
    FROM playlist_track a
    JOIN playlist_track b ON b.track_id = a.track_id AND b.playlist_id > a.playlist_id
    GROUP BY ALL
)
SELECT pa.name || ' (#' || s.a || ')'                                AS playlist_a,
       pb.name || ' (#' || s.b || ')'                                AS playlist_b,
       sa.tracks AS tracks_a, sb.tracks AS tracks_b, s.common,
       round(s.common / (sa.tracks + sb.tracks - s.common), 3)        AS jaccard
FROM shared s
JOIN sizes sa ON sa.playlist_id = s.a
JOIN sizes sb ON sb.playlist_id = s.b
JOIN playlist pa ON pa.playlist_id = s.a
JOIN playlist pb ON pb.playlist_id = s.b
WHERE s.common >= 10
ORDER BY jaccard DESC, s.common DESC
LIMIT 10;

-- name: revenue_grouping_sets
-- Revenue by media type, by year, and in total, in one pass (GROUPING SETS).
SELECT CASE WHEN grouping(mt.name) = 1 THEN 'All media' ELSE mt.name END          AS media_type,
       CASE WHEN grouping(year(i.invoice_date)) = 1 THEN 'All years'
            ELSE year(i.invoice_date)::VARCHAR END                                AS year,
       sum(il.quantity)                                                           AS tracks_sold,
       sum(il.unit_price * il.quantity)                                           AS revenue
FROM invoice_line il
JOIN invoice i USING (invoice_id)
JOIN track t USING (track_id)
JOIN media_type mt USING (media_type_id)
GROUP BY GROUPING SETS ((mt.name), (year(i.invoice_date)), ())
ORDER BY grouping(mt.name), grouping(year(i.invoice_date)), revenue DESC, year;
