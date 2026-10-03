# Chinook Music Store: sales analysis on a relational database

The classic **Chinook** database (a digital music store: 11 tables, 412 invoices, 3,503 tracks) copied from SQLite into DuckDB as a fully constrained relational model (primary keys, foreign keys including a self-reference, exact `DECIMAL` money), then analyzed with joins, window functions, recursive CTEs and relational division.

> Chinook is a **sample database with generated sales**, which makes it ideal for practicing relational SQL. Its time trends are artificially flat (monthly revenue is $37.62 almost every month), so this project focuses on structure: who buys what, where, and through which rep.

![Revenue by genre](images/revenue_by_genre.png)

## Questions
1. Is the data consistent (invoice totals vs invoice lines, orphan lines)?
2. Which countries and genres generate the revenue?
3. How does revenue evolve year over year?
4. How do the three sales reps compare?
5. How is customer lifetime value distributed?
6. Who is the best-selling artist in each market?
7. How much of the catalog never sells?
8. What does the reporting hierarchy look like, and how much revenue sits under each manager? (recursive CTE, transitive closure)
9. Does anyone buy complete albums? (relational division)
10. Which playlists overlap? (Jaccard similarity from a self-join)
11. Revenue by media type, by year and in total, in one query (`GROUPING SETS`)

## Key findings
- **Clean data:** all 412 invoice totals match the sum of their lines, and no line points to a missing track.
- **Rock is 35.5% of track revenue,** followed by Latin (16.4%) and Metal (11.2%). Video content (TV Shows, Drama) sells few units but at $1.99 a track.
- **The USA (22.5%) and Canada (13.1%) bring in over a third of revenue.** Revenue per customer barely varies ($37–46), so market size is simply the number of customers.
- **Flat sales:** 2009–2013 revenue stays between $449 and $481 a year (YoY between −5.6% and +7.1%), a sign of generated data.
- **Sales reps:** Jane Peacock leads with $833 over 21 customers, against $720 for Steve Johnson (18 customers).
- **Iron Maiden is the top artist in 4 of the 8 biggest markets** (USA, Germany, Portugal, Czech Republic).
- **43.4% of the catalog (1,519 of 3,503 tracks) has never been sold,** and over half of the protected video files.
- **Lifetime value is almost constant:** 30 of the 59 customers (50.8%) have spent exactly $37.62. With ties like this, `ntile()` quartiles would put identical customers in different quartiles, so the query reports the actual distribution instead.
- **Org chart:** the General Manager has two branches. Sales (Nancy Edwards → 3 support agents) handles all 59 customers and $2,328.60 of revenue. IT (Michael Mitchell → 2 staff) handles none.
- **Nobody ever buys a complete album:** among 1,254 invoice/album pairs (albums with 2+ tracks), **0** contain every track of the album, although invoices have up to 14 lines. This is another trace of generated sales.
- **Duplicate playlists:** "Music" #1 and #8 are identical (Jaccard 1.0, 3,290 tracks each), and so are "TV Shows" #3 and #10. "90's Music" is a strict subset of "Music".

| Revenue by country | Unsold catalog |
|---|---|
| ![Countries](images/revenue_by_country.png) | ![Coverage](images/catalog_coverage.png) |

## SQL techniques
- Loading from another database engine (`ATTACH ... (TYPE sqlite)`) and renaming to a clean snake_case model
- **Integrity checks** with scalar subqueries and anti-joins (`LEFT JOIN ... WHERE ... IS NULL`)
- Window functions: `lag()` for YoY growth, rolling average, `rank()`, `row_number()` **top-N per group**, a cumulative count over a value distribution
- **Declared relational model:** `PRIMARY KEY`, `FOREIGN KEY` on every relationship, a **self-referencing foreign key** (employee → manager, loaded level by level because DuckDB checks the key against the table as it was before the statement), a composite key on the playlist bridge table, `CHECK`s, and `DECIMAL(10,2)` money (the source's floating-point totals produced values like `37.620000000000005`)
- **Recursive CTEs:** a hierarchy walk with the path as a list, and a **transitive closure** (every manager × every employee below them) to roll revenue up the org chart
- **Relational division** with a double `NOT EXISTS` ("no track of the album is missing from the invoice")
- **Jaccard similarity** from a self-join of a many-to-many bridge table
- **`GROUPING SETS`** with `grouping()` labels
- `FILTER (WHERE ...)` aggregates, 6-table joins, CTE pipelines

## Dataset
| | |
|---|---|
| Source | [lerocha/chinook-database](https://github.com/lerocha/chinook-database) (release v1.4.5) |
| Size | 11 tables, 412 invoices, 2,240 invoice lines, 59 customers, 3,503 tracks |
| License | MIT |

## Run it
```bash
pip install -r ../../requirements.txt
python run.py
```
