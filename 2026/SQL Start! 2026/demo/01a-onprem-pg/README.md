# Alternativa API PostgreSQL

Questa è la variante PostgreSQL della demo SQL Server locale. Pubblica tabelle e vista PostgreSQL tramite Data API builder (DAB), usando lo stesso dominio assicurativo e una forma dell’API quasi identica a quella di ../01-onprem/.

## Prerequisiti

- Un’istanza PostgreSQL in esecuzione con il database InsuranceDemo
- PostgreSQL 17 o una versione compatibile
- Data API builder CLI 2.0.x (dab)

Questa cartella non contiene una configurazione Docker Compose. run.sh presuppone che il database sia già disponibile; il comando Docker presente nello script è intenzionalmente disabilitato.

## Preparazione del database

Carica le variabili d’ambiente della sessione ed esegui gli script nell’ordine indicato:

~~~bash
set -a; . ../../.env; set +a
psql "$PG_CONN" -f sql/01a-schema.sql
psql "$PG_CONN" -f sql/02-seed.sql
~~~

Aggiungi PG_CONN a ../../.env, per esempio:

~~~dotenv
PG_CONN="Host=localhost;Port=5432;Database=InsuranceDemo;Username=postgres;Password=<password>"
~~~

Usa un formato di stringa di connessione supportato dal provider Npgsql nella tua installazione di DAB.

## Avvio

Dalla cartella di questa demo:

~~~bash
./run.sh
~~~

Lo script ricrea dab-config.json e avvia DAB sulla porta 5000. Per ricreare soltanto la configurazione:

~~~bash
./build-config.sh
dab validate
~~~

## Endpoint API

| URL | Scopo |
|---|---|
| http://localhost:5000/health | Stato del servizio |
| http://localhost:5000/api/openapi | Documento OpenAPI e Swagger UI |
| http://localhost:5000/api/policies | Tabella public.policies |
| http://localhost:5000/api/brokers | Tabella public.brokers |
| http://localhost:5000/api/policy-summary | Vista public.vw_policysummary |
| http://localhost:5000/graphql | Endpoint GraphQL |
| http://localhost:5000/mcp | Endpoint MCP |

La vista è esposta come entità di sola lettura e usa policy_id come chiave. Lo schema contiene anche usp_renewpolicy come funzione PostgreSQL, ma la configurazione DAB presente nel repository pubblica solo tabelle e vista.

## Configurazione

build-config.sh usa @env('PG_CONN'), quindi la password non viene salvata in dab-config.json. La configurazione generata non richiede autenticazione ed è destinata soltanto allo sviluppo locale.

La demo PostgreSQL è un’alternativa a 01-onprem e non è una dipendenza delle altre demo. Le demo che usano SQL Server locale richiedono invece ../01-onprem/.

