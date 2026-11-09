-- Estensioni e tabelle. Tema delle slide: tutto in un solo motore.
CREATE EXTENSION IF NOT EXISTS pg_trgm;   -- trusted: fornita con PostgreSQL
CREATE EXTENSION IF NOT EXISTS vector;    -- pgvector: estensione esterna al core

CREATE SCHEMA shop;
SET search_path = shop, public;

-- ---------------------------------------------------------------- clienti
CREATE TABLE customers (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code        text NOT NULL UNIQUE,
    name        text NOT NULL,
    email       text,
    region      text NOT NULL CHECK (region IN ('bergamo', 'milano', 'roma')),
    profile     jsonb NOT NULL DEFAULT '{}',      -- JSONB: dati documentali variabili
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX customers_name_trgm  ON customers USING gin (name gin_trgm_ops);   -- pg_trgm
CREATE INDEX customers_profile_gin ON customers USING gin (profile jsonb_path_ops);
CREATE INDEX customers_region_idx ON customers (region);

-- --------------------------------------------------------------- prodotti
CREATE TABLE products (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku          text NOT NULL UNIQUE,
    name         text NOT NULL,
    description  text NOT NULL DEFAULT '',
    category     text NOT NULL,
    price        numeric(10, 2) NOT NULL CHECK (price >= 0),
    stock        integer NOT NULL DEFAULT 0 CHECK (stock >= 0),
    attributes   jsonb NOT NULL DEFAULT '{}',     -- JSONB: attributi diversi per categoria
    -- Full Text Search: colonna generata con pesi (nome A, descrizione B, categoria C)
    search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('italian', coalesce(name, '')),        'A') ||
        setweight(to_tsvector('italian', coalesce(description, '')), 'B') ||
        setweight(to_tsvector('italian', coalesce(category, '')),    'C')
    ) STORED,
    -- pgvector: calcolato fuori dal database (sidecar), dimensione fissata a 256
    embedding    vector(256),
    created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX products_search_gin   ON products USING gin (search_vector);
CREATE INDEX products_name_trgm    ON products USING gin (name gin_trgm_ops);
-- jsonb_path_ops: più piccolo e veloce, ma solo @>, @?, @@ (niente operatore ?)
CREATE INDEX products_attr_path    ON products USING gin (attributes jsonb_path_ops);
-- indice su espressione: serve per interrogare con ? un sotto-oggetto
CREATE INDEX products_attr_conn    ON products USING gin ((attributes -> 'connessioni'));
-- HNSW sulla distanza coseno: la classe di operatori deve combaciare con <=>
CREATE INDEX products_embedding_hnsw ON products USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- Parole del catalogo per i suggerimenti "forse cercavi..." (si rigenera: refresh_product_words)
CREATE TABLE product_words (word text PRIMARY KEY);
CREATE INDEX product_words_trgm ON product_words USING gin (word gin_trgm_ops);

-- ----------------------------------------------------------------- ordini
CREATE SEQUENCE order_number_seq;

CREATE TABLE orders (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_number  text NOT NULL UNIQUE DEFAULT
                  ('ORD-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('shop.order_number_seq')::text, 6, '0')),
    customer_id   bigint NOT NULL REFERENCES customers (id),
    -- regione denormalizzata: le policy RLS guardano solo la riga corrente (nessuna sub-SELECT)
    region        text NOT NULL CHECK (region IN ('bergamo', 'milano', 'roma')),
    status        text NOT NULL DEFAULT 'new'
                  CHECK (status IN ('new', 'confirmed', 'paid', 'shipped', 'delivered', 'cancelled')),
    placed_at     timestamptz NOT NULL DEFAULT now(),
    total         numeric(12, 2) NOT NULL DEFAULT 0,
    shipping      jsonb NOT NULL DEFAULT '{}',    -- JSONB: indirizzo, corriere, note di consegna
    notes         text,
    updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX orders_customer_idx ON orders (customer_id);
CREATE INDEX orders_status_idx   ON orders (status);
CREATE INDEX orders_region_placed_idx ON orders (region, placed_at DESC);
CREATE INDEX orders_shipping_gin ON orders USING gin (shipping jsonb_path_ops);

CREATE TABLE order_items (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id    bigint NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    product_id  bigint NOT NULL REFERENCES products (id),
    region      text NOT NULL CHECK (region IN ('bergamo', 'milano', 'roma')),
    quantity    integer NOT NULL CHECK (quantity > 0),
    unit_price  numeric(10, 2) NOT NULL CHECK (unit_price >= 0),
    UNIQUE (order_id, product_id)
);

-- Fatti persistiti: la NOTIFY segnala, la tabella conserva
CREATE TABLE order_events (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id      bigint NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    region        text NOT NULL,
    event_type    text NOT NULL,
    old_status    text,
    new_status    text,
    changed_by    text NOT NULL DEFAULT session_user,
    created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX order_events_order_idx ON order_events (order_id, created_at DESC);
