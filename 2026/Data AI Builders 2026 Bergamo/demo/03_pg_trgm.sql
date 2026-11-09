\set ON_ERROR_STOP on
\timing on

\echo '=== pg_trgm: typo, fuzzy matching e autocomplete ==='

CREATE EXTENSION IF NOT EXISTS pg_trgm;

DROP SCHEMA IF EXISTS demo_trgm CASCADE;
CREATE SCHEMA demo_trgm;

CREATE TABLE demo_trgm.products (
    id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku      text NOT NULL UNIQUE,
    name     text NOT NULL,
    category text NOT NULL
);

INSERT INTO demo_trgm.products (sku, name, category) VALUES
    ('AUD-001', 'Microfono bluetooth da tavolo', 'audio'),
    ('AUD-002', 'Microfono USB cardioide', 'audio'),
    ('AUD-003', 'Cuffie bluetooth cancellazione rumore', 'audio'),
    ('NET-001', 'Router Wi-Fi mesh', 'network'),
    ('NET-002', 'Adattatore bluetooth USB', 'network');

CREATE INDEX products_name_trgm_idx
    ON demo_trgm.products USING gin (name gin_trgm_ops);

\echo '-- Ricerca approssimata: la query contiene un refuso'
SELECT sku,
       name,
       round(similarity(name, 'microfono bluetooh')::numeric, 3) AS similarity
FROM demo_trgm.products
WHERE name % 'microfono bluetooh'
ORDER BY similarity DESC, sku;

\echo '-- Ordinamento per distanza trigrammi'
SELECT sku,
       name,
       round((name <-> 'microfono bluetooth')::numeric, 3) AS distance
FROM demo_trgm.products
ORDER BY name <-> 'microfono bluetooth'
LIMIT 5;
