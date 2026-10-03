-- Index benchmarks on 778,784 sales lines in PostgreSQL (run by toolkit/postgres.py).
-- Each query is timed with the primary keys only, then after creating the index(es) listed in its
-- "-- index:" lines; the result must not change. Indexes are dropped between queries.

-- name: customer_history
-- One customer's purchase history, newest first: the typical "my orders" page of a shop.
-- A composite index on (customer_id, invoiced_at DESC) finds the rows and returns them pre-sorted.
-- index: CREATE INDEX sales_customer_time ON sales (customer_id, invoiced_at DESC)
SELECT invoice, invoiced_at, stock_code, quantity, revenue
FROM sales
WHERE customer_id = 12360
ORDER BY invoiced_at DESC, line_id;

-- name: invoice_btree
-- All lines of one invoice, by its number, with a B-tree.
-- index: CREATE INDEX sales_invoice_btree ON sales (invoice)
SELECT line_id, stock_code, quantity, revenue
FROM sales
WHERE invoice = '576339'
ORDER BY line_id;

-- name: invoice_hash
-- The same lookup with a hash index (equality only: no ranges, no sorting). The textbook says it is
-- smaller because it stores a 4-byte hash instead of the key, but B-tree deduplication (PostgreSQL 13+)
-- stores each invoice number once for all its ~21 lines: here the B-tree is 4x smaller. Measure first.
-- index: CREATE INDEX sales_invoice_hash ON sales USING hash (invoice)
SELECT line_id, stock_code, quantity, revenue
FROM sales
WHERE invoice = '576339'
ORDER BY line_id;

-- name: fuzzy_search
-- Product search box: lines whose description contains "babushka", anywhere, any case. A B-tree can't
-- serve a leading wildcard; a trigram GIN index splits the text into 3-letter pieces and can.
-- index: CREATE INDEX sales_description_trgm ON sales USING gin (description gin_trgm_ops)
SELECT description, count(*) AS lines, sum(revenue) AS revenue
FROM sales
WHERE description ILIKE '%babushka%'
GROUP BY description
ORDER BY revenue DESC, description;

-- name: case_insensitive
-- Exact product name typed in any case. lower(description) = ... needs an index on lower(description).
-- index: CREATE INDEX sales_description_lower ON sales (lower(description))
SELECT count(*) AS lines, sum(quantity) AS units, sum(revenue) AS revenue
FROM sales
WHERE lower(description) = 'regency cakestand 3 tier';

-- name: customer_totals_covering
-- Lifetime value of a group of customers. The covering index answers from the index alone.
-- index: CREATE INDEX sales_customer_cover ON sales (customer_id) INCLUDE (invoice, revenue)
SELECT customer_id, count(DISTINCT invoice) AS orders, sum(revenue) AS revenue
FROM sales
WHERE customer_id BETWEEN 12360 AND 12400
GROUP BY customer_id
ORDER BY customer_id;

-- name: latest_order_lateral
-- The latest purchase of every German customer: a LATERAL subquery with ORDER BY ... LIMIT 1 runs
-- once per customer. With an index on (customer_id, invoiced_at DESC) each run is one index probe.
-- index: CREATE INDEX sales_customer_time ON sales (customer_id, invoiced_at DESC)
SELECT c.customer_id, l.invoice, l.invoiced_at
FROM customers c
CROSS JOIN LATERAL (
    SELECT s.invoice, s.invoiced_at
    FROM sales s
    WHERE s.customer_id = c.customer_id
    ORDER BY s.invoiced_at DESC, s.invoice DESC
    LIMIT 1
) l
WHERE c.country = 'Germany'
ORDER BY c.customer_id;

-- name: unsold_products
-- Anti-join: products with no sale since June 2011. With an index on (stock_code, invoiced_at) every
-- NOT EXISTS probe becomes a single index lookup, instead of hashing all recent sales.
-- index: CREATE INDEX sales_product_time ON sales (stock_code, invoiced_at)
SELECT count(*) AS products_not_sold_since_june_2011
FROM products p
WHERE NOT EXISTS (
    SELECT 1 FROM sales s
    WHERE s.stock_code = p.stock_code AND s.invoiced_at >= '2011-06-01'
);

-- name: month_brin
-- Revenue per day in November 2011, the busiest month. BRIN works because lines are stored in time order.
-- index: CREATE INDEX sales_time_brin ON sales USING brin (invoiced_at)
SELECT invoiced_at::date AS day, count(DISTINCT invoice) AS orders, sum(revenue) AS revenue
FROM sales
WHERE invoiced_at >= '2011-11-01' AND invoiced_at < '2011-12-01'
GROUP BY 1
ORDER BY 1;
