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
-- Split customers into lifetime-value quartiles (NTILE) and compare the groups.
WITH ltv AS (
    SELECT customer_id, sum(total) AS lifetime_value, count(*) AS orders
    FROM invoice
    GROUP BY customer_id
), q AS (
    SELECT *, ntile(4) OVER (ORDER BY lifetime_value DESC) AS quartile FROM ltv
)
SELECT quartile,
       count(*)                          AS customers,
       round(min(lifetime_value), 2)     AS min_ltv,
       round(max(lifetime_value), 2)     AS max_ltv,
       round(sum(lifetime_value), 2)     AS revenue,
       round(avg(orders), 1)             AS avg_orders
FROM q
GROUP BY quartile
ORDER BY quartile;

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
ORDER BY country_tracks DESC
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
