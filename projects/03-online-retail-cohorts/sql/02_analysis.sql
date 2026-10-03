-- name: data_quality
-- What did cleaning remove, and why?
SELECT quality,
       count(*)                                            AS lines,
       round(100.0 * count(*) / sum(count(*)) OVER (), 2)  AS pct
FROM line_quality
GROUP BY quality
ORDER BY lines DESC;

-- name: sheet_overlap
-- Proof of the overlap between the two Excel sheets.
SELECT sheet, min(invoiced_at) AS first_line, max(invoiced_at) AS last_line, count(*) AS lines
FROM lines_typed
GROUP BY sheet
ORDER BY sheet;

-- name: monthly_revenue
-- Monthly revenue, orders and active customers (Dec 2011 is a partial month).
SELECT date_trunc('month', invoiced_at)          AS month,
       round(sum(revenue), 0)                     AS revenue,
       count(DISTINCT invoice)                    AS orders,
       count(DISTINCT customer_id)                AS active_customers,
       max(invoiced_at)                           AS last_order_in_month
FROM sales
GROUP BY month
ORDER BY month;

-- name: cohort_retention
-- Of the customers who first bought in month M, what % bought again k months later?
WITH activity AS (
    SELECT DISTINCT s.customer_id,
           date_trunc('month', c.first_purchase_at) AS cohort,
           date_diff('month', date_trunc('month', c.first_purchase_at), date_trunc('month', s.invoiced_at)) AS month_number
    FROM sales s
    JOIN customers c USING (customer_id)
), sizes AS (
    SELECT cohort, count(*) AS cohort_size FROM activity WHERE month_number = 0 GROUP BY cohort
)
SELECT a.cohort, s.cohort_size, a.month_number,
       count(*)                                         AS active_customers,
       round(100.0 * count(*) / s.cohort_size, 1)       AS retention_pct
FROM activity a
JOIN sizes s USING (cohort)
WHERE a.cohort < DATE '2011-01-01' AND a.month_number <= 12
GROUP BY a.cohort, s.cohort_size, a.month_number
ORDER BY a.cohort, a.month_number;

-- name: rfm_segments
-- RFM: score each customer 1-5 on Recency, Frequency, Monetary value, then group into segments.
WITH snapshot AS (SELECT max(invoiced_at) + INTERVAL 1 DAY AS ts FROM sales),
scores AS (
    SELECT c.customer_id, c.revenue,
           date_diff('day', c.last_purchase_at, (SELECT ts FROM snapshot)) AS recency_days,
           ntile(5) OVER (ORDER BY c.last_purchase_at)  AS r,   -- 5 = bought most recently
           ntile(5) OVER (ORDER BY c.orders)            AS f,
           ntile(5) OVER (ORDER BY c.revenue)           AS m
    FROM customers c
), segmented AS (
    SELECT *,
           CASE
               WHEN r >= 4 AND f >= 4 AND m >= 4 THEN '1. Champions'
               WHEN r >= 3 AND f >= 3            THEN '2. Loyal'
               WHEN r >= 4 AND f <= 2            THEN '3. New / promising'
               WHEN r <= 2 AND f >= 3            THEN '4. At risk'
               WHEN r <= 2 AND f <= 2            THEN '5. Lost'
               ELSE                                   '6. Need attention'
           END AS segment
    FROM scores
)
SELECT segment,
       count(*)                                                        AS customers,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1)              AS customers_pct,
       round(sum(revenue), 0)                                          AS revenue,
       round(100.0 * sum(revenue) / sum(sum(revenue)) OVER (), 1)      AS revenue_pct,
       round(median(recency_days), 0)                                  AS median_recency_days
FROM segmented
GROUP BY segment
ORDER BY segment;

-- name: pareto
-- What share of customers produces 80% of revenue? (cumulative window)
WITH ranked AS (
    SELECT revenue,
           sum(revenue) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING) / sum(revenue) OVER () AS cum_share,
           row_number() OVER (ORDER BY revenue DESC)                                                AS rn,
           count(*) OVER ()                                                                         AS n
    FROM customers
)
SELECT min(rn)                                  AS customers_for_80pct,
       any_value(n)                             AS total_customers,
       round(100.0 * min(rn) / any_value(n), 1) AS pct_of_customers
FROM ranked
WHERE cum_share >= 0.8;

-- name: top_products
-- Best-selling products by revenue.
SELECT stock_code, any_value(description) AS description,
       sum(quantity) AS units, round(sum(revenue), 0) AS revenue,
       count(DISTINCT customer_id) AS customers
FROM sales
GROUP BY stock_code
ORDER BY revenue DESC
LIMIT 10;

-- name: countries
-- Revenue and average order value by country (top 10).
SELECT country,
       count(DISTINCT customer_id)                              AS customers,
       round(sum(revenue), 0)                                   AS revenue,
       round(sum(revenue) / count(DISTINCT invoice), 2)         AS avg_order_value,
       round(100.0 * sum(revenue) / sum(sum(revenue)) OVER (), 1) AS share_pct
FROM sales
GROUP BY country
ORDER BY revenue DESC
LIMIT 10;
