\set ON_ERROR_STOP on
\timing on

\echo '=== LISTEN/NOTIFY: segnalare un cambiamento senza perdere il fatto ==='

DROP SCHEMA IF EXISTS demo_events CASCADE;
CREATE SCHEMA demo_events;

CREATE TABLE demo_events.orders (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer    text NOT NULL,
    status      text NOT NULL CHECK (status IN ('paid', 'pending')),
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION demo_events.notify_order_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM pg_notify(
        'demo_order_events',
        json_build_object(
            'id', NEW.id,
            'customer', NEW.customer,
            'status', NEW.status
        )::text
    );
    RETURN NEW;
END;
$$;

CREATE TRIGGER orders_notify_change
AFTER INSERT OR UPDATE ON demo_events.orders
FOR EACH ROW
EXECUTE FUNCTION demo_events.notify_order_change();

\echo 'Setup completato. Aprire ora un secondo terminale per il listener.'
