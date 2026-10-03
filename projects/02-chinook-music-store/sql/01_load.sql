-- Chinook: a digital music store (customers, invoices, tracks, artists, employees, playlists).
-- Copy every table out of the SQLite file into DuckDB with snake_case names, and declare the
-- relational model the source only implies: primary keys, foreign keys (including the employee ->
-- manager self-reference), CHECKs, and exact DECIMAL money instead of floating point.

INSTALL sqlite;
LOAD sqlite;
ATTACH 'data/chinook.sqlite' AS src (TYPE sqlite, READ_ONLY);

-- Children before parents: DuckDB refuses to drop a table that a foreign key still points to.
DROP TABLE IF EXISTS playlist_track;
DROP TABLE IF EXISTS playlist;
DROP TABLE IF EXISTS invoice_line;
DROP TABLE IF EXISTS invoice;
DROP TABLE IF EXISTS customer;
DROP TABLE IF EXISTS employee;
DROP TABLE IF EXISTS track;
DROP TABLE IF EXISTS album;
DROP TABLE IF EXISTS artist;
DROP TABLE IF EXISTS genre;
DROP TABLE IF EXISTS media_type;

CREATE TABLE artist (
    artist_id INTEGER PRIMARY KEY,
    name      VARCHAR
);
INSERT INTO artist SELECT ArtistId, Name FROM src.Artist;

CREATE TABLE album (
    album_id  INTEGER PRIMARY KEY,
    title     VARCHAR NOT NULL,
    artist_id INTEGER NOT NULL REFERENCES artist (artist_id)
);
INSERT INTO album SELECT AlbumId, Title, ArtistId FROM src.Album;

CREATE TABLE genre (
    genre_id INTEGER PRIMARY KEY,
    name     VARCHAR
);
INSERT INTO genre SELECT GenreId, Name FROM src.Genre;

CREATE TABLE media_type (
    media_type_id INTEGER PRIMARY KEY,
    name          VARCHAR
);
INSERT INTO media_type SELECT MediaTypeId, Name FROM src.MediaType;

CREATE TABLE track (
    track_id      INTEGER PRIMARY KEY,
    name          VARCHAR NOT NULL,
    album_id      INTEGER REFERENCES album (album_id),
    media_type_id INTEGER NOT NULL REFERENCES media_type (media_type_id),
    genre_id      INTEGER REFERENCES genre (genre_id),
    composer      VARCHAR,
    milliseconds  INTEGER NOT NULL CHECK (milliseconds > 0),
    bytes         INTEGER,
    unit_price    DECIMAL(10, 2) NOT NULL CHECK (unit_price > 0)
);
INSERT INTO track
SELECT TrackId, Name, AlbumId, MediaTypeId, GenreId, Composer, Milliseconds, Bytes, UnitPrice
FROM src.Track;

-- Self-referencing foreign key: every manager must be an employee. DuckDB checks a foreign key
-- against the table as it was before the statement, so the hierarchy is inserted one level at a
-- time, top down, using each employee's depth from a recursive CTE (Chinook has 3 levels).
CREATE TABLE employee (
    employee_id INTEGER PRIMARY KEY,
    name        VARCHAR NOT NULL,
    title       VARCHAR,
    reports_to  INTEGER REFERENCES employee (employee_id),
    hire_date   DATE,
    country     VARCHAR,
    CHECK (reports_to <> employee_id)
);
CREATE OR REPLACE TEMP TABLE employee_src AS
WITH RECURSIVE levels(employee_id, depth) AS (
    SELECT EmployeeId, 0 FROM src.Employee WHERE ReportsTo IS NULL
    UNION ALL
    SELECT e.EmployeeId, l.depth + 1 FROM src.Employee e JOIN levels l ON e.ReportsTo = l.employee_id
)
SELECT e.EmployeeId AS employee_id, e.FirstName || ' ' || e.LastName AS name, e.Title AS title,
       e.ReportsTo AS reports_to, CAST(e.HireDate AS DATE) AS hire_date, e.Country AS country, l.depth
FROM src.Employee e JOIN levels l ON l.employee_id = e.EmployeeId;
INSERT INTO employee SELECT * EXCLUDE (depth) FROM employee_src WHERE depth = 0;
INSERT INTO employee SELECT * EXCLUDE (depth) FROM employee_src WHERE depth = 1;
INSERT INTO employee SELECT * EXCLUDE (depth) FROM employee_src WHERE depth = 2;

CREATE TABLE customer (
    customer_id    INTEGER PRIMARY KEY,
    name           VARCHAR NOT NULL,
    company        VARCHAR,
    city           VARCHAR,
    country        VARCHAR,
    support_rep_id INTEGER REFERENCES employee (employee_id)
);
INSERT INTO customer
SELECT CustomerId, FirstName || ' ' || LastName, Company, City, Country, SupportRepId
FROM src.Customer;

CREATE TABLE invoice (
    invoice_id      INTEGER PRIMARY KEY,
    customer_id     INTEGER NOT NULL REFERENCES customer (customer_id),
    invoice_date    DATE NOT NULL,
    billing_country VARCHAR,
    total           DECIMAL(10, 2) NOT NULL CHECK (total >= 0)
);
INSERT INTO invoice
SELECT InvoiceId, CustomerId, CAST(InvoiceDate AS DATE), BillingCountry, Total
FROM src.Invoice;

CREATE TABLE invoice_line (
    invoice_line_id INTEGER PRIMARY KEY,
    invoice_id      INTEGER NOT NULL REFERENCES invoice (invoice_id),
    track_id        INTEGER NOT NULL REFERENCES track (track_id),
    unit_price      DECIMAL(10, 2) NOT NULL CHECK (unit_price > 0),
    quantity        INTEGER NOT NULL CHECK (quantity > 0)
);
INSERT INTO invoice_line
SELECT InvoiceLineId, InvoiceId, TrackId, UnitPrice, Quantity
FROM src.InvoiceLine;

CREATE TABLE playlist (
    playlist_id INTEGER PRIMARY KEY,
    name        VARCHAR
);
INSERT INTO playlist SELECT PlaylistId, Name FROM src.Playlist;

-- Many-to-many bridge table: composite primary key, a foreign key to each side.
CREATE TABLE playlist_track (
    playlist_id INTEGER NOT NULL REFERENCES playlist (playlist_id),
    track_id    INTEGER NOT NULL REFERENCES track (track_id),
    PRIMARY KEY (playlist_id, track_id)
);
INSERT INTO playlist_track SELECT PlaylistId, TrackId FROM src.PlaylistTrack;

DETACH src;
