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
           -- Quintile scores 1-5 from percent_rank(), not ntile(): 1,614 customers have exactly one order,
           -- and ntile() would split those ties between scores 1 and 2 arbitrarily. Equal values, equal scores.
           least(5, 1 + floor(5 * percent_rank() OVER (ORDER BY c.last_purchase_at)))::INT AS r,  -- 5 = most recent
           least(5, 1 + floor(5 * percent_rank() OVER (ORDER BY c.orders)))::INT           AS f,
           least(5, 1 + floor(5 * percent_rank() OVER (ORDER BY c.revenue)))::INT          AS m
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

-- ============================================================================================
-- Advanced SQL
-- ============================================================================================

-- name: repeat_purchase
-- How long until a customer comes back? Days between consecutive orders (LAG over each customer's
-- orders), by order number, and how many customers ever reach that order.
WITH orders AS (
    SELECT customer_id, invoice, min(invoiced_at) AS ordered_at
    FROM sales
    GROUP BY ALL
), numbered AS (
    SELECT customer_id,
           row_number() OVER w                                         AS order_number,
           date_diff('day', lag(ordered_at) OVER w, ordered_at)        AS days_since_previous
    FROM orders
    WINDOW w AS (PARTITION BY customer_id ORDER BY ordered_at, invoice)
)
SELECT order_number,
       count(*)                                                          AS customers,
       round(100.0 * count(*) / max(count(*)) OVER (), 1)                AS pct_of_customers,
       median(days_since_previous)                                       AS median_days_since_previous,
       round(avg(days_since_previous), 1)                                AS avg_days_since_previous
FROM numbered
WHERE order_number <= 10
GROUP BY order_number
ORDER BY order_number;

-- name: market_basket
-- Which products are bought together? Self-join of invoice lines into product pairs, then
-- support, confidence and lift (lift > 1: the pair is bought together more often than chance).
WITH baskets AS (
    SELECT DISTINCT invoice, stock_code FROM sales
), n AS (SELECT count(DISTINCT invoice) AS invoices FROM baskets),
item AS (
    SELECT stock_code, count(*) AS invoices FROM baskets GROUP BY stock_code
    HAVING count(*) >= 300                     -- products in 300+ orders keep the self-join small
), pairs AS (
    SELECT a.stock_code AS a, b.stock_code AS b, count(*) AS together
    FROM baskets a
    JOIN baskets b ON b.invoice = a.invoice AND b.stock_code > a.stock_code
    WHERE a.stock_code IN (SELECT stock_code FROM item) AND b.stock_code IN (SELECT stock_code FROM item)
    GROUP BY ALL
    HAVING count(*) >= 200
)
SELECT pa.description AS product_a, pb.description AS product_b,
       p.together                                                   AS orders_together,
       round(100.0 * p.together / n.invoices, 2)                    AS support_pct,
       round(100.0 * p.together / ia.invoices, 1)                   AS confidence_a_to_b_pct,
       round(p.together * n.invoices / (ia.invoices * ib.invoices), 1) AS lift
FROM pairs p, n
JOIN item ia ON ia.stock_code = p.a
JOIN item ib ON ib.stock_code = p.b
JOIN products pa ON pa.stock_code = p.a
JOIN products pb ON pb.stock_code = p.b
ORDER BY lift DESC
LIMIT 10;

-- name: activity_streaks
-- Gaps and islands: each customer's runs of consecutive active months. A run is a set of months whose
-- (month index - row number) is constant. How long is each customer's longest streak?
WITH active AS (
    SELECT DISTINCT customer_id, date_trunc('month', invoiced_at) AS month FROM sales
), islands AS (
    SELECT customer_id, month,
           date_diff('month', DATE '2009-12-01', month)
             - row_number() OVER (PARTITION BY customer_id ORDER BY month) AS island
    FROM active
), runs AS (
    SELECT customer_id, island, count(*) AS months, min(month) AS run_start
    FROM islands GROUP BY ALL
), longest AS (
    SELECT customer_id, max(months) AS longest_streak FROM runs GROUP BY customer_id
)
SELECT CASE WHEN longest_streak >= 12 THEN '12+' ELSE longest_streak::VARCHAR END AS longest_streak_months,
       count(*) AS customers,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct,
       round(avg(c.revenue), 0) AS avg_revenue
FROM longest l JOIN customers c USING (customer_id)
GROUP BY ALL
ORDER BY min(longest_streak);

-- name: revenue_cube
-- Revenue by market and year with every subtotal (CUBE = all combinations of the grouping columns).
-- 2009 is December only and 2011 stops on 9 December.
SELECT CASE WHEN grouping(market) = 1 THEN 'All markets' ELSE market END AS market,
       CASE WHEN grouping(year) = 1 THEN 'All years' ELSE year::VARCHAR END AS year,
       count(DISTINCT customer_id) AS customers,
       round(sum(revenue), 0) AS revenue,
       round(sum(revenue) / count(DISTINCT invoice), 2) AS avg_order_value
FROM (SELECT *, CASE WHEN country = 'United Kingdom' THEN 'United Kingdom'
                     WHEN country IN ('Austria','Belgium','Cyprus','Denmark','Finland','France','Germany','Greece','Ireland','EIRE','Italy','Lithuania','Malta','Netherlands','Poland','Portugal','Spain','Sweden','Czech Republic','European Community','Channel Islands','Iceland','Norway','Switzerland') THEN 'Rest of Europe'
                     ELSE 'Rest of world' END AS market,
             year(invoiced_at) AS year
      FROM sales)
GROUP BY CUBE (market, year)
ORDER BY grouping(market), market, grouping(year), year;
