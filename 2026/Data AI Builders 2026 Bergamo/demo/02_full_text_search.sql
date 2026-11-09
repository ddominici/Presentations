\set ON_ERROR_STOP on
\timing on

\echo '=== Full Text Search: tokenizzazione, ranking e indice ==='

DROP SCHEMA IF EXISTS demo_fts CASCADE;
CREATE SCHEMA demo_fts;

CREATE TABLE demo_fts.articles (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title           text NOT NULL,
    body            text NOT NULL,
    search_document tsvector GENERATED ALWAYS AS (
        to_tsvector('italian', coalesce(title, '') || ' ' || coalesce(body, ''))
    ) STORED
);

INSERT INTO demo_fts.articles (title, body) VALUES
    ('PostgreSQL per applicazioni web',
     'Un database relazionale può gestire dati applicativi, ricerca testuale e policy.'),
    ('Ricerca testuale con ranking',
     'La ricerca full text tokenizza il documento e ordina i risultati per rilevanza.'),
    ('Architettura distribuita',
     'Un motore esterno può essere utile quando scala, latenza o ownership sono indipendenti.');

CREATE INDEX articles_search_document_gin_idx
    ON demo_fts.articles USING gin (search_document);

\echo '-- Query linguistica: stemming e ranking'
WITH query AS (
    SELECT websearch_to_tsquery('italian', 'database ricerca') AS q
)
SELECT a.id,
       a.title,
       ts_rank_cd(a.search_document, query.q) AS rank
FROM demo_fts.articles AS a
CROSS JOIN query
WHERE a.search_document @@ query.q
ORDER BY rank DESC, a.id;

\echo '-- Query pronta per essere passata da una web application'
SELECT title
FROM demo_fts.articles
WHERE search_document @@ websearch_to_tsquery('italian', '"ricerca testuale"');
