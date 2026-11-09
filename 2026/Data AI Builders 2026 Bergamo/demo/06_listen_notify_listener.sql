\set ON_ERROR_STOP on

\echo 'Listener attivo: lasciare aperta questa sessione psql.'
LISTEN demo_order_events;
SELECT now() AS listener_started;
