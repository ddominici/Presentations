\set ON_ERROR_STOP on
\timing on

\echo '=== Row Level Security: il tenant è parte del confine dati ==='

DROP SCHEMA IF EXISTS demo_rls CASCADE;
CREATE SCHEMA demo_rls;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'demo_app') THEN
        CREATE ROLE demo_app NOLOGIN;
    END IF;
END
$$;

CREATE TABLE demo_rls.orders (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id   text NOT NULL,
    customer    text NOT NULL,
    total       numeric(10, 2) NOT NULL CHECK (total >= 0),
    status      text NOT NULL CHECK (status IN ('paid', 'pending'))
);

INSERT INTO demo_rls.orders (tenant_id, customer, total, status) VALUES
    ('bergamo', 'Acme Bergamo', 120.00, 'paid'),
    ('bergamo', 'Beta Bergamo', 49.00, 'pending'),
    ('milano', 'Gamma Milano', 75.00, 'paid');

ALTER TABLE demo_rls.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE demo_rls.orders FORCE ROW LEVEL SECURITY;

CREATE POLICY orders_by_tenant ON demo_rls.orders
    USING (tenant_id = current_setting('app.tenant_id', true))
    WITH CHECK (tenant_id = current_setting('app.tenant_id', true));

GRANT USAGE ON SCHEMA demo_rls TO demo_app;
GRANT SELECT ON demo_rls.orders TO demo_app;

\echo '-- La stessa query applicativa, con due contesti di sessione'
SET ROLE demo_app;

BEGIN;
SET LOCAL app.tenant_id = 'bergamo';
SELECT id, tenant_id, customer, total
FROM demo_rls.orders
ORDER BY id;
COMMIT;

BEGIN;
SET LOCAL app.tenant_id = 'milano';
SELECT id, tenant_id, customer, total
FROM demo_rls.orders
ORDER BY id;
COMMIT;

RESET ROLE;
