-- Funzioni di ricerca e scrittura, esposte dal backend (Data API Builder) come stored-procedure.
-- Tutte SECURITY INVOKER (default): RLS e grant del ruolo chiamante restano validi.
SET search_path = shop, public;

-- ============================================================ JSONB
-- Contenimento (@>), esistenza chiave (?), SQL/JSON path (@?) sugli attributi prodotto.
CREATE FUNCTION find_products_by_attributes(
    p_contains text DEFAULT NULL,
    p_has_key  text DEFAULT NULL,
    p_path     text DEFAULT NULL
) RETURNS TABLE (id bigint, sku text, name text, category text, price numeric, attributes jsonb)
LANGUAGE sql STABLE SET search_path = shop, public AS $$
    SELECT p.id, p.sku, p.name, p.category, p.price, p.attributes
      FROM products p
     WHERE (p_contains IS NULL OR p.attributes @> p_contains::jsonb)
       AND (p_has_key  IS NULL OR p.attributes ? p_has_key)
       AND (p_path     IS NULL OR p.attributes @? p_path::jsonpath)
     ORDER BY p.name
     LIMIT 100
$$;

-- ============================================================ Full Text Search
CREATE FUNCTION search_products_fts(p_query text, p_limit integer DEFAULT 20)
RETURNS TABLE (id bigint, sku text, name text, category text, price numeric, rank real, headline text)
LANGUAGE sql STABLE SET search_path = shop, public AS $$
    WITH q AS (SELECT websearch_to_tsquery('italian', p_query) AS tsq)
    SELECT p.id, p.sku, p.name, p.category, p.price,
           ts_rank(p.search_vector, q.tsq),
           ts_headline('italian', p.description, q.tsq,
                       'StartSel=<mark>,StopSel=</mark>,MaxFragments=1,MaxWords=30,MinWords=10')
      FROM products p, q
     WHERE p.search_vector @@ q.tsq
     ORDER BY 6 DESC, p.id
     LIMIT p_limit
$$;

-- Mostra le tre fasi: parsing -> lexemi -> tsvector / tsquery
CREATE FUNCTION explain_text_search(p_text text)
RETURNS TABLE (tsvector_text text, tsquery_text text, phrase_text text)
LANGUAGE sql STABLE SET search_path = shop, public AS $$
    SELECT to_tsvector('italian', p_text)::text,
           websearch_to_tsquery('italian', p_text)::text,
           phraseto_tsquery('italian', p_text)::text
$$;

-- ============================================================ pg_trgm
CREATE FUNCTION search_customers(p_query text, p_threshold real DEFAULT 0.3)
RETURNS TABLE (id bigint, code text, name text, email text, region text, score real)
LANGUAGE plpgsql STABLE SET search_path = shop, public AS $$
BEGIN
    -- soglie degli operatori % e <%, valide solo per questa transazione/istruzione
    PERFORM set_config('pg_trgm.similarity_threshold', p_threshold::text, true);
    PERFORM set_config('pg_trgm.word_similarity_threshold', p_threshold::text, true);
    RETURN QUERY
    SELECT c.id, c.code, c.name, c.email, c.region,
           GREATEST(similarity(c.name, p_query), word_similarity(p_query, c.name))
      FROM customers c
     WHERE c.name % p_query OR p_query <% c.name OR c.name ILIKE '%' || p_query || '%'   -- tutti serviti dall'indice trigram
     ORDER BY 6 DESC, c.name
     LIMIT 30;
END $$;

CREATE FUNCTION search_products_fuzzy(p_query text, p_threshold real DEFAULT 0.3)
RETURNS TABLE (id bigint, sku text, name text, category text, price numeric,
               similarity real, word_similarity real, strict_word_similarity real)
LANGUAGE plpgsql STABLE SET search_path = shop, public AS $$
BEGIN
    PERFORM set_config('pg_trgm.similarity_threshold', p_threshold::text, true);
    PERFORM set_config('pg_trgm.word_similarity_threshold', p_threshold::text, true);
    RETURN QUERY
    SELECT p.id, p.sku, p.name, p.category, p.price,
           similarity(p.name, p_query),
           word_similarity(p_query, p.name),
           strict_word_similarity(p_query, p.name)
      FROM products p
     WHERE p.name % p_query OR p_query <% p.name
     ORDER BY GREATEST(similarity(p.name, p_query), word_similarity(p_query, p.name)) DESC, p.name
     LIMIT 20;
END $$;

CREATE FUNCTION trigrams_of(p_text text) RETURNS TABLE (trigram text)
LANGUAGE sql STABLE AS $$ SELECT unnest(show_trgm(p_text)) $$;

-- "Forse cercavi...": FTS + pg_trgm sulle parole del catalogo (tabella statica, da rigenerare)
CREATE FUNCTION refresh_product_words() RETURNS bigint
LANGUAGE plpgsql SET search_path = shop, public AS $$
DECLARE n bigint;
BEGIN
    TRUNCATE product_words;
    INSERT INTO product_words (word)
    SELECT word FROM ts_stat('SELECT to_tsvector(''simple'', name || '' '' || description) FROM shop.products')
     WHERE length(word) > 3;
    GET DIAGNOSTICS n = ROW_COUNT;
    RETURN n;
END $$;

CREATE FUNCTION suggest_terms(p_term text)
RETURNS TABLE (word text, score real)
LANGUAGE sql STABLE SET search_path = shop, public AS $$
    SELECT w.word, similarity(w.word, lower(p_term))
      FROM product_words w
     WHERE w.word % lower(p_term)
     ORDER BY 2 DESC, 1
     LIMIT 5
$$;

-- ============================================================ pgvector
-- L'embedding della query è calcolato fuori dal database (sidecar) e passato come testo '[...]'.
CREATE FUNCTION search_products_semantic(p_embedding text, p_limit integer DEFAULT 10)
RETURNS TABLE (id bigint, sku text, name text, category text, price numeric, distance double precision)
LANGUAGE sql STABLE SET search_path = shop, public AS $$
    SELECT p.id, p.sku, p.name, p.category, p.price, p.embedding <=> p_embedding::vector
      FROM products p
     WHERE p.embedding IS NOT NULL
     ORDER BY p.embedding <=> p_embedding::vector
     LIMIT p_limit
$$;

CREATE FUNCTION similar_products(p_product_id bigint, p_limit integer DEFAULT 5)
RETURNS TABLE (id bigint, sku text, name text, category text, price numeric, distance double precision)
LANGUAGE sql STABLE SET search_path = shop, public AS $$
    SELECT p.id, p.sku, p.name, p.category, p.price, p.embedding <=> src.embedding
      FROM products p, (SELECT embedding FROM products WHERE id = p_product_id) src
     WHERE p.id <> p_product_id AND p.embedding IS NOT NULL AND src.embedding IS NOT NULL
     ORDER BY p.embedding <=> src.embedding
     LIMIT p_limit
$$;

-- Ricerca ibrida: FTS + vettoriale uniti con Reciprocal Rank Fusion, score = sum(1 / (k + rank)), k = 60
CREATE FUNCTION search_products_hybrid(p_query text, p_embedding text, p_limit integer DEFAULT 10)
RETURNS TABLE (id bigint, sku text, name text, category text, price numeric,
               fts_rank integer, semantic_rank integer, rrf_score double precision)
LANGUAGE sql STABLE SET search_path = shop, public AS $$
    WITH fts AS (
        SELECT p.id, row_number() OVER (ORDER BY ts_rank(p.search_vector, q.tsq) DESC, p.id)::integer AS rnk
          FROM products p, (SELECT websearch_to_tsquery('italian', p_query) AS tsq) q
         WHERE p.search_vector @@ q.tsq
         LIMIT 20
    ), sem AS (
        SELECT p.id, row_number() OVER (ORDER BY p.embedding <=> p_embedding::vector)::integer AS rnk
          FROM products p
         WHERE p.embedding IS NOT NULL
         ORDER BY p.embedding <=> p_embedding::vector
         LIMIT 20
    )
    SELECT p.id, p.sku, p.name, p.category, p.price, fts.rnk, sem.rnk,
           coalesce(1.0 / (60 + fts.rnk), 0) + coalesce(1.0 / (60 + sem.rnk), 0)
      FROM fts FULL JOIN sem ON sem.id = fts.id
      JOIN products p ON p.id = coalesce(fts.id, sem.id)
     ORDER BY 8 DESC, p.id
     LIMIT p_limit
$$;

-- ============================================================ Ordini
-- Creazione atomica: ordine + righe. Invoker: la regione del cliente deve essere visibile
-- al chiamante (RLS), altrimenti il cliente "non esiste".
CREATE FUNCTION create_order(
    p_customer_id bigint,
    p_items       jsonb,
    p_shipping    jsonb DEFAULT '{}',
    p_notes       text DEFAULT NULL
) RETURNS TABLE (id bigint, order_number text, total numeric)
LANGUAGE plpgsql SET search_path = shop, public AS $$
DECLARE
    v_region text;
    v_id     bigint;
BEGIN
    SELECT c.region INTO v_region FROM customers c WHERE c.id = p_customer_id;
    IF v_region IS NULL THEN
        RAISE EXCEPTION 'Cliente % non trovato o non accessibile', p_customer_id
            USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF jsonb_typeof(p_items) IS DISTINCT FROM 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Un ordine richiede almeno una riga' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    INSERT INTO orders (customer_id, region, shipping, notes)
    VALUES (p_customer_id, v_region, COALESCE(p_shipping, '{}'), p_notes)
    RETURNING orders.id INTO v_id;

    INSERT INTO order_items (order_id, product_id, region, quantity, unit_price)
    SELECT v_id, pr.id, v_region, sum((i ->> 'quantity')::integer), pr.price
      FROM jsonb_array_elements(p_items) i
      JOIN products pr ON pr.id = (i ->> 'product_id')::bigint
     GROUP BY pr.id, pr.price;

    IF NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = v_id) THEN
        RAISE EXCEPTION 'Nessun prodotto valido nelle righe' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    RETURN QUERY SELECT o.id, o.order_number, o.total FROM orders o WHERE o.id = v_id;
END $$;

-- ============================================================ Viste (security_invoker: RLS del chiamante)
-- Senza security_invoker una vista gira coi privilegi del proprietario e bypassa RLS.
CREATE VIEW v_orders_overview WITH (security_invoker = true) AS
SELECT o.id, o.order_number, o.status, o.region, o.placed_at, o.total, o.notes,
       o.customer_id, c.name AS customer_name,
       o.shipping ->> 'citta' AS ship_city,
       o.shipping ->> 'corriere' AS carrier,
       (SELECT count(*) FROM order_items i WHERE i.order_id = o.id)::integer AS items_count
  FROM orders o
  JOIN customers c ON c.id = o.customer_id;

CREATE VIEW v_order_stats WITH (security_invoker = true) AS
SELECT status, count(*)::integer AS orders_count, coalesce(sum(total), 0) AS revenue
  FROM orders
 GROUP BY status;

CREATE VIEW v_orders_daily WITH (security_invoker = true) AS
SELECT placed_at::date AS day, count(*)::integer AS orders_count, coalesce(sum(total), 0) AS revenue
  FROM orders
 WHERE status <> 'cancelled'
 GROUP BY placed_at::date;

CREATE VIEW v_order_lines WITH (security_invoker = true) AS
SELECT i.id, i.order_id, i.product_id, p.sku, p.name AS product_name,
       i.quantity, i.unit_price, (i.quantity * i.unit_price) AS line_total
  FROM order_items i
  JOIN products p ON p.id = i.product_id;

CREATE VIEW v_products_public WITH (security_invoker = true) AS
SELECT id, sku, name, description, category, price, stock, attributes FROM products;

GRANT SELECT ON ALL TABLES IN SCHEMA shop TO shop_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA shop TO shop_app;
