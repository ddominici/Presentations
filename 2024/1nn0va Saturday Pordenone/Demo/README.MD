# Architetture dati complesse e dove trovarle

### Step 1 - L'infrastruttura

Questa demo utilizza Docker su Mac.

Viene creata una infrastruttura basata su 6 servizi:
- Kafka
- Kafka Connect
- Zookeper (il servizio di heartbeating per il cluster Kafka - anche se qui utilizziamo un solo nodo)
- akhq (il client web per Kafka)
- sql server 2022
- postgres 16

Per accendere l'infrastruttura (o crearla è la prima volta che si esegue), eseguire il comando:

    docker compose up


### Step 2 - Configurare i database origine e destinazione

Se è la prima volta che si eseguono i containers, il server SQL non contiene il database di esempio e quindi va inizializzato con il comando:

    cat sqlserver/init_sqlserver.sql | docker exec -i sql-2022 bash -c '/opt/mssql-tools18/bin/sqlcmd -S 127.0.0.1 -U sa -P P@ssw0rd?!? -C'

Il server Postgres all'interno del container invece è già stato inizializzato tramite lo script init-schema.sql.

Se doveste utilizzare un Azure SQL for Postgres potete creare il database orderdb e inizializzarlo con i comandi:

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


### Step 3 - Registrare i connettori Kafka per origine e destinazione

Connettore di origine SQL Server

curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @register-sqlserver-source.json

Connettore di destinazione PostgreSQL

curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @register-postgres-sink.json

A questo punto, aprendo l'interfaccia web di Kafka (http://localhost:8080) dovreste vedere nell'elenco dei topics le tabelle dal database SQL Server e, collegandosi al server Postgresql, le tabelle replicate dal topic per products e orders.

Elencare i connettori installati

curl -i -X GET http://localhost:8083/connectors -w "\n"


### Step 4 - Installare e configurare Data API Builder

La versione attuale (29 settembre 2024) è la 1.2.11, ma tenete d'occhio il repository GitHub per le evoluzioni: https://github.com/Azure/data-api-builder

Per far funzionare la demo occorre creare una vista per l'elenco dei prodotti e degli ordini.
Creare la vista utilizzando il contenuto del file postgresql\create_view.sql

    CREATE OR REPLACE VIEW purchaseorder.v_products
    AS
    SELECT id,
        name,
        description,
        weight
    FROM purchaseorder."src_testDB_dbo_products";

    ALTER TABLE purchaseorder.v_products
        OWNER TO orderuser;

Quindi installare Data API Builder seguendo le istruzioni fornite nel sito https://learn.microsoft.com/en-us/azure/data-api-builder/how-to-install-cli

Posizionarsi nella cartella dab ed eseguire il Data API Builder con il comando:

    dab start

Se tutto funziona dovreste vedere nella quartultima riga del log il link: http://localhost:5000. Cliccandoci sopra si apre la pagina delle informazioni di stato del DAB.

Per verificare che il metodo GET /products funzioni è sufficiente lanciare il comando:

    curl -v http://localhost:5000/api/products


That's all!