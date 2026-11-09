-- Row Level Security: chi vede quali righe lo decide il database.
SET search_path = shop, public;

-- Helper row-local: nessuna sub-SELECT nelle policy (caso più semplice e performante).
-- Il contesto arriva da ALTER ROLE ... SET app.region (vedi 00_roles.sh).
CREATE FUNCTION current_region() RETURNS text
LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('app.region', true), '') $$;

CREATE FUNCTION is_manager() RETURNS boolean
LANGUAGE sql STABLE AS $$ SELECT coalesce(current_setting('app.region', true), '') = '*' $$;

-- ------------------------------------------------------------- privilegi
GRANT USAGE ON SCHEMA shop TO shop_app;
GRANT SELECT ON ALL TABLES IN SCHEMA shop TO shop_app;
GRANT USAGE ON SEQUENCE order_number_seq TO shop_app;
GRANT EXECUTE ON FUNCTION current_region(), is_manager() TO shop_app;

-- I venditori gestiscono ordini e clienti; il catalogo è in sola lettura (permission denied).
GRANT INSERT, UPDATE, DELETE ON orders, order_items TO shop_app;
GRANT INSERT, UPDATE ON customers TO shop_app;
GRANT INSERT, UPDATE, DELETE ON products TO shop_manager;
GRANT INSERT, UPDATE, DELETE ON customers TO shop_manager;
GRANT TRUNCATE ON orders TO shop_manager;  -- TRUNCATE non è soggetta a RLS

-- ------------------------------------------------------------------ RLS
ALTER TABLE customers    ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders       ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items  ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_events ENABLE ROW LEVEL SECURITY;
-- Il proprietario (superuser dello script) bypassa comunque RLS: i ruoli applicativi
-- non sono proprietari né BYPASSRLS, quindi le policy si applicano sempre.
-- Con RLS abilitata e nessuna policy varrebbe il default-deny.

-- USING = righe esistenti visibili; WITH CHECK = righe nuove/modificate ammesse.
CREATE POLICY customers_by_region ON customers TO shop_app
    USING      (is_manager() OR region = current_region())
    WITH CHECK (is_manager() OR region = current_region());

CREATE POLICY orders_by_region ON orders TO shop_app
    USING      (is_manager() OR region = current_region())
    WITH CHECK (is_manager() OR region = current_region());

CREATE POLICY order_items_by_region ON order_items TO shop_app
    USING      (is_manager() OR region = current_region())
    WITH CHECK (is_manager() OR region = current_region());

CREATE POLICY order_events_by_region ON order_events FOR SELECT TO shop_app
    USING (is_manager() OR region = current_region());

-- Policy RESTRICTIVE: combinate in AND con le permissive, devono sempre passare.
-- Ordini chiusi modificabili solo dal manager. WITH CHECK (true) esplicito: senza,
-- varrebbe l'espressione di USING anche sulla riga nuova e 'shipped -> delivered' verrebbe rifiutato.
CREATE POLICY orders_closed_are_readonly ON orders AS RESTRICTIVE FOR UPDATE TO shop_app
    USING      (is_manager() OR status NOT IN ('delivered', 'cancelled'))
    WITH CHECK (true);

-- Si cancellano solo ordini ancora 'new' (il manager può tutto).
CREATE POLICY orders_delete_only_new ON orders AS RESTRICTIVE FOR DELETE TO shop_app
    USING (is_manager() OR status = 'new');
