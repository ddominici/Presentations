# SQL Start! 2024 - Architetture dati complesse e dove trovarle

Spoiler: Using Debezium to sync SQL Server with PostgreSQL

### Step 1 - Accendere l'infrastruttura

Eseguire docker compose up per scaricare/eseguire tutti i containers parte della soluzione.

Se è la prima volta che si eseguono i containers, il server SQL non contiene il database di esempio e
quindi va inizializzato con il comando:

cat sqlserver/init_sqlserver.sql | docker exec -i demosql2022 bash -c '/opt/mssql-tools/bin/sqlcmd -U sa -P P@ssw0rd?!?'



### Step 2 - Registrare i connettori Kafka per origine e destinazione

Connettore di origine SQL Server

curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @register-sqlserver-source.json

Connettore di destinazione PostgreSQL

curl -i -X POST -H "Accept:application/json" -H  "Content-Type:application/json" http://localhost:8083/connectors/ -d @register-postgres-sink.json

Elencare i connettori installati

curl -i -X GET http://localhost:8083/connectors -w "\n"


### Step 3 - Installare e configurare Data API Builder

dotnet tool install --global Microsoft.DataApiBuilder

La versione attuale è la 1.1.7, ma tenete d'occhio il repository GitHub per le evoluzioni: https://github.com/Azure/data-api-builder

dab init --database-type "postgresql" --host-mode "Development" --connection-string "Host=localhost;Port=5432;Database=orderdb;User ID=orderuser;Password=orderpw;"

dab add Products --source "purchaseorder.v_products" --permissions "anonymous:read"

dab start
