-- The clean Online Retail star schema in PostgreSQL, filled from DuckDB by toolkit/postgres.py.
-- Only constraint indexes exist here (primary keys); every other index is created and measured by
-- sql/04_index_benchmarks.sql. Money is NUMERIC so sums are exact, whatever the plan.

-- Trigram operators for the fuzzy-search benchmark (contrib extension, shipped with PostgreSQL).
CREATE EXTENSION IF NOT EXISTS pg_trgm SCHEMA public;

CREATE TABLE products (
    stock_code  text PRIMARY KEY,
    description text NOT NULL
);

CREATE TABLE customers (
    customer_id       integer PRIMARY KEY,
    country           text NOT NULL,
    first_purchase_at timestamp NOT NULL,
    last_purchase_at  timestamp NOT NULL,
    orders            integer NOT NULL CHECK (orders > 0),
    revenue           numeric(12, 2) NOT NULL CHECK (revenue > 0),
    CHECK (last_purchase_at >= first_purchase_at)
);

CREATE TABLE sales (
    line_id     integer PRIMARY KEY,
    invoice     text NOT NULL,
    -- Postgres does NOT index foreign keys automatically.
    stock_code  text NOT NULL REFERENCES products,
    description text,
    quantity    integer NOT NULL CHECK (quantity > 0),
    invoiced_at timestamp NOT NULL,
    unit_price  numeric(10, 2) NOT NULL CHECK (unit_price > 0),
    revenue     numeric(12, 2) NOT NULL,
    customer_id integer NOT NULL REFERENCES customers,
    country     text NOT NULL
);

-- Lines in invoice-time order, as the shop's order feed wrote them (lets BRIN work on invoiced_at).
-- source: sales = SELECT line_id, invoice, stock_code, description, quantity, invoiced_at, unit_price, revenue, customer_id, country FROM sales ORDER BY line_id
