\set ON_ERROR_STOP on
\timing on

INSERT INTO demo_events.orders (customer, status)
VALUES ('Acme Bergamo', 'paid')
RETURNING id, customer, status, created_at;

\echo 'La transazione è stata confermata: il listener dovrebbe ricevere la notifica.'
