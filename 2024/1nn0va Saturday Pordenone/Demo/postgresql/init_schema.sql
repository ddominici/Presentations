-- Creazione del nuovo schema 'purchaseorder' se non esiste
CREATE SCHEMA IF NOT EXISTS purchaseorder;

-- Creazione del nuovo utente 'orderuser' se non esiste
DO
$$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'orderuser') THEN
        CREATE USER orderuser WITH PASSWORD 'orderpw';
    END IF;
END
$$;

-- Assegnazione dei permessi all'utente 'orderuser'
GRANT CONNECT ON DATABASE orderdb TO orderuser;
GRANT USAGE ON SCHEMA purchaseorder TO orderuser;
GRANT CREATE ON SCHEMA purchaseorder TO orderuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA purchaseorder TO orderuser;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA purchaseorder TO orderuser;

-- Impostazione di default per i nuovi oggetti
ALTER DEFAULT PRIVILEGES IN SCHEMA purchaseorder
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO orderuser;
