-- Online Retail II (UCI): every line item of a UK online gift retailer, Dec 2009 - Dec 2011,
-- delivered as an Excel workbook with one sheet per year.

INSTALL excel;
LOAD excel;

-- Read both sheets as text (the Invoice column mixes numbers and 'C...' cancellations).
CREATE OR REPLACE TABLE raw_lines AS
SELECT 'Year 2009-2010' AS sheet, * FROM read_xlsx('data/online_retail_II.xlsx', sheet = 'Year 2009-2010', all_varchar = true)
UNION ALL BY NAME
SELECT 'Year 2010-2011' AS sheet, * FROM read_xlsx('data/online_retail_II.xlsx', sheet = 'Year 2010-2011', all_varchar = true);

-- Type every column. Excel stores dates as days since 1899-12-30.
CREATE OR REPLACE TABLE lines_typed AS
SELECT
    sheet,
    Invoice                                                                     AS invoice,
    StockCode                                                                   AS stock_code,
    trim(Description)                                                           AS description,
    CAST(Quantity AS INTEGER)                                                   AS quantity,
    TIMESTAMP '1899-12-30' + to_milliseconds(CAST(round(CAST(InvoiceDate AS DOUBLE) * 86400000) AS BIGINT)) AS invoiced_at,
    round(CAST(Price AS DOUBLE), 2)                                             AS unit_price,
    CAST(CAST("Customer ID" AS DOUBLE) AS INTEGER)                              AS customer_id,
    Country                                                                     AS country
FROM raw_lines;

-- The two sheets overlap: rows of the first sheet dated on/after the second sheet's start are duplicates.
-- A purchase later reversed by a cancellation line (same customer, product and quantity) never really happened.
CREATE OR REPLACE TABLE line_quality AS
WITH overlap_start AS (SELECT min(invoiced_at) AS ts FROM lines_typed WHERE sheet = 'Year 2010-2011'),
deduped AS (
    SELECT * FROM lines_typed
    WHERE NOT (sheet = 'Year 2009-2010' AND invoiced_at >= (SELECT ts FROM overlap_start))
),
cancellations AS (
    SELECT customer_id, stock_code, -quantity AS quantity, invoiced_at
    FROM deduped
    WHERE starts_with(invoice, 'C') AND customer_id IS NOT NULL
)
SELECT l.*,
       CASE
           WHEN l.sheet = 'Year 2009-2010' AND l.invoiced_at >= (SELECT ts FROM overlap_start) THEN 'duplicate across sheets'
           WHEN starts_with(l.invoice, 'C')                                 THEN 'cancellation'
           WHEN EXISTS (SELECT 1 FROM cancellations c
                        WHERE c.customer_id = l.customer_id AND c.stock_code = l.stock_code
                          AND c.quantity = l.quantity AND c.invoiced_at >= l.invoiced_at)
                                                                             THEN 'order cancelled afterwards'
           WHEN NOT regexp_matches(l.stock_code, '^[0-9]{5}')               THEN 'non-product line (postage, fees, adjustments)'
           WHEN l.quantity <= 0 OR l.unit_price <= 0                         THEN 'non-positive quantity or price'
           WHEN l.customer_id IS NULL                                        THEN 'no customer id'
           ELSE 'ok'
       END AS quality
FROM lines_typed l;

-- Star schema with enforced keys: sales (fact, one row per clean line) -> customers, products.
-- DuckDB refuses to replace a table a foreign key points to, so drop the fact table first.
DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS products;

-- One row per product. 595 stock codes appear under several descriptions (typos, renames):
-- keep the most frequent one.
CREATE TABLE products (
    stock_code  VARCHAR PRIMARY KEY,
    description VARCHAR NOT NULL
);
INSERT INTO products
SELECT stock_code, mode(description)
FROM line_quality
WHERE quality = 'ok'
GROUP BY stock_code;

-- One row per customer: first purchase, last purchase, orders, revenue (used by cohort and RFM queries).
CREATE TABLE customers (
    customer_id       INTEGER PRIMARY KEY,
    country           VARCHAR NOT NULL,
    first_purchase_at TIMESTAMP NOT NULL,
    last_purchase_at  TIMESTAMP NOT NULL,
    orders            INTEGER NOT NULL CHECK (orders > 0),
    revenue           DOUBLE NOT NULL CHECK (revenue > 0),
    CHECK (last_purchase_at >= first_purchase_at)
);
INSERT INTO customers
SELECT customer_id,
       mode(country)                                        AS country,
       min(invoiced_at)                                     AS first_purchase_at,
       max(invoiced_at)                                     AS last_purchase_at,
       count(DISTINCT invoice)                              AS orders,
       round(sum(round(quantity * unit_price, 2)), 2)       AS revenue
FROM line_quality
WHERE quality = 'ok'
GROUP BY customer_id;

CREATE TABLE sales (
    line_id     INTEGER PRIMARY KEY,
    invoice     VARCHAR NOT NULL,
    stock_code  VARCHAR NOT NULL REFERENCES products (stock_code),
    description VARCHAR,
    quantity    INTEGER NOT NULL CHECK (quantity > 0),
    invoiced_at TIMESTAMP NOT NULL,
    unit_price  DOUBLE NOT NULL CHECK (unit_price > 0),
    revenue     DOUBLE NOT NULL,
    customer_id INTEGER NOT NULL REFERENCES customers (customer_id),
    country     VARCHAR NOT NULL
);
INSERT INTO sales
SELECT row_number() OVER (ORDER BY invoiced_at, invoice, stock_code, quantity, unit_price) AS line_id,
       invoice, stock_code, description, quantity, invoiced_at, unit_price,
       round(quantity * unit_price, 2) AS revenue, customer_id, country
FROM line_quality
WHERE quality = 'ok'
ORDER BY line_id;
