set ON_ERROR_STOP on
timing on


echo '=== JSONB: schema flessibile dentro una tabella relazionale ==='

DROP SCHEMA IF EXISTS demo_jsonb CASCADE;
CREATE SCHEMA demo_jsonb;

CREATE TABLE demo_jsonb.products (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku         text NOT NULL UNIQUE,
    name        text NOT NULL,
    price       numeric(10, 2) NOT NULL CHECK (price >= 0),
    metadata    jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at  timestamptz NOT NULL DEFAULT now()
);

INSERT INTO demo_jsonb.products (sku, name, price, metadata) VALUES
    ('pg-101', 'PostgreSQL handbook', 39.00,
     '{"color":"blue", "stock":12, "tags":["database","web"], "dimensions":{"pages":320}}'),
    ('pg-102', 'SQL performance clinic', 59.00,
     '{"color":"red", "stock":4, "tags":["database","performance"], "dimensions":{"pages":280}}'),
    ('pg-103', 'Distributed systems notes', 44.00,
     '{"color":"blue", "stock":0, "tags":["architecture","web"]}');

-- L'indice GIN accelera gli operatori JSONB come @>.
CREATE INDEX products_metadata_gin_idx
    ON demo_jsonb.products USING gin (metadata);

SELECT * FROM demo_jsonb.products;

-- Attributo documentale letto con gli operatori JSONB
SELECT sku,
       name,
       metadata ->> 'color' AS color,
       (metadata ->> 'stock')::int AS stock
FROM demo_jsonb.products
ORDER BY sku;

\echo '-- Filtro documentale: prodotto blu con tag web'
SELECT sku, name
FROM demo_jsonb.products
WHERE metadata @> '{"color":"blue", "tags":["web"]}'::jsonb
ORDER BY sku;

\echo '-- Il modello può evolvere senza ALTER TABLE'
UPDATE demo_jsonb.products
SET metadata = jsonb_set(metadata, '{delivery}', '{"days":2,"carrier":"express"}'::jsonb)
WHERE sku = 'pg-101';

SELECT sku,
       metadata #>> '{delivery,carrier}' AS carrier,
       (metadata #>> '{delivery,days}')::int AS delivery_days
FROM demo_jsonb.products
WHERE sku = 'pg-101';

SELECT *
FROM demo_jsonb.products
WHERE sku = 'pg-101';
