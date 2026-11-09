\set ON_ERROR_STOP on
\timing on

\echo '=== pgvector: similarità semantica nello stesso modello dati ==='

CREATE EXTENSION IF NOT EXISTS vector;

DROP SCHEMA IF EXISTS demo_vector CASCADE;
CREATE SCHEMA demo_vector;

CREATE TABLE demo_vector.documents (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id   text NOT NULL,
    title       text NOT NULL,
    body        text NOT NULL,
    embedding   vector(3) NOT NULL
);

INSERT INTO demo_vector.documents (tenant_id, title, body, embedding) VALUES
    ('bergamo', 'JSONB in PostgreSQL',
     'Attributi variabili e dati documentali dentro una tabella SQL.', '[0.95, 0.10, 0.05]'),
    ('bergamo', 'Ricerca testuale',
     'Tokenizzazione, ranking e ricerca full text.', '[0.80, 0.25, 0.10]'),
    ('bergamo', 'Row Level Security',
     'Policy per limitare le righe visibili a ciascun tenant.', '[0.15, 0.90, 0.10]'),
    ('milano', 'Vector search',
     'Ricerca semantica e nearest-neighbor con embedding.', '[0.90, 0.12, 0.06]');

-- Per dataset piccoli la query esatta è sufficiente; HNSW diventa utile
-- quando il numero di vettori e il profilo di latenza lo giustificano.
CREATE INDEX documents_embedding_hnsw_idx
    ON demo_vector.documents
    USING hnsw (embedding vector_cosine_ops);

\echo '-- Query semantica, vincolata dal tenant'
SELECT title,
       1 - (embedding <=> '[0.92, 0.12, 0.08]'::vector) AS cosine_similarity
FROM demo_vector.documents
WHERE tenant_id = 'bergamo'
ORDER BY embedding <=> '[0.92, 0.12, 0.08]'::vector
LIMIT 3;

\echo '-- La similarità non sostituisce i filtri di business'
SELECT title, tenant_id
FROM demo_vector.documents
WHERE tenant_id = 'bergamo'
ORDER BY embedding <=> '[0.92, 0.12, 0.08]'::vector
LIMIT 3;
