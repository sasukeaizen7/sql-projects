-- Chinook: a digital music store (customers, invoices, tracks, artists, employees).
-- Copy every table out of the SQLite file into DuckDB with snake_case names.

INSTALL sqlite;
LOAD sqlite;
ATTACH 'data/chinook.sqlite' AS src (TYPE sqlite, READ_ONLY);

CREATE OR REPLACE TABLE artist         AS SELECT ArtistId AS artist_id, Name AS name FROM src.Artist;
CREATE OR REPLACE TABLE album          AS SELECT AlbumId AS album_id, Title AS title, ArtistId AS artist_id FROM src.Album;
CREATE OR REPLACE TABLE genre          AS SELECT GenreId AS genre_id, Name AS name FROM src.Genre;
CREATE OR REPLACE TABLE media_type     AS SELECT MediaTypeId AS media_type_id, Name AS name FROM src.MediaType;
CREATE OR REPLACE TABLE track          AS
SELECT TrackId AS track_id, Name AS name, AlbumId AS album_id, MediaTypeId AS media_type_id, GenreId AS genre_id,
       Composer AS composer, Milliseconds AS milliseconds, Bytes AS bytes, UnitPrice AS unit_price
FROM src.Track;
CREATE OR REPLACE TABLE employee       AS
SELECT EmployeeId AS employee_id, FirstName || ' ' || LastName AS name, Title AS title, ReportsTo AS reports_to,
       CAST(HireDate AS DATE) AS hire_date, Country AS country
FROM src.Employee;
CREATE OR REPLACE TABLE customer       AS
SELECT CustomerId AS customer_id, FirstName || ' ' || LastName AS name, Company AS company, City AS city,
       Country AS country, SupportRepId AS support_rep_id
FROM src.Customer;
CREATE OR REPLACE TABLE invoice        AS
SELECT InvoiceId AS invoice_id, CustomerId AS customer_id, CAST(InvoiceDate AS DATE) AS invoice_date,
       BillingCountry AS billing_country, Total AS total
FROM src.Invoice;
CREATE OR REPLACE TABLE invoice_line   AS
SELECT InvoiceLineId AS invoice_line_id, InvoiceId AS invoice_id, TrackId AS track_id, UnitPrice AS unit_price, Quantity AS quantity
FROM src.InvoiceLine;

DETACH src;
