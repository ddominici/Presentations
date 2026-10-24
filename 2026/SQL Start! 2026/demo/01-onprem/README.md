# API SQL Server locale

Questa demo espone un database SQL Server esistente tramite Data API builder (DAB). Tabelle, vista, stored procedure e relazione diventano endpoint REST, GraphQL e MCP senza modificare lo schema del database.

## Prerequisiti

- Docker Desktop
- Data API builder CLI 2.0.x (dab)
- curl (opzionale; gli esempi funzionano anche con VS Code REST Client)

## Configurazione

Dalla cartella della sessione:

~~~bash
cp .env.example .env
~~~

Imposta MSSQL_SA_PASSWORD e SQL_CONN nel file .env. La stringa di connessione deve puntare al database InsuranceDemo su localhost,1433 e usare la stessa password del container SQL Server. Mantieni privato il file .env.

## Avvio

Dalla cartella di questa demo, esegui la configurazione completa:

~~~bash
./run.sh
~~~

Lo script avvia SQL Server 2022, attende che sia disponibile, crea schema e dati di esempio dalla cartella sql/, ricrea dab-config.json, lo valida e avvia DAB sulla porta 5000.

Per eseguire i passaggi separatamente:

~~~bash
docker compose up -d
./build-config.sh
dab start
~~~

## Endpoint API

Quando DAB è in esecuzione:

| URL | Scopo |
|---|---|
| http://localhost:5000/health | Stato del servizio |
| http://localhost:5000/api/openapi | Documento OpenAPI e Swagger UI |
| http://localhost:5000/api/policies | Tabella delle polizze |
| http://localhost:5000/api/brokers | Tabella dei broker |
| http://localhost:5000/api/policy-summary | Vista vw_PolicySummary |
| http://localhost:5000/api/renew-policy | Stored procedure usp_RenewPolicy |
| http://localhost:5000/graphql | Endpoint GraphQL |
| http://localhost:5000/mcp | Endpoint MCP |

Il file requests.http contiene esempi di lettura, filtro, proiezione, inserimento, aggiornamento, GraphQL ed esecuzione della stored procedure. Il client React opzionale è descritto in webapp/README.md.

Esempi:

~~~bash
curl 'http://localhost:5000/api/policies?$filter=status%20eq%20%27active%27&$orderby=premium%20desc&$first=5'
curl 'http://localhost:5000/api/policy-summary'
~~~

La relazione GraphQL permette di includere il broker nella stessa richiesta di una polizza. La vista dichiara policy_id come chiave perché DAB non può ricavare automaticamente una chiave da una vista. RenewPolicy è disponibile come endpoint POST e come custom tool MCP.

## Ricreazione e reset

build-config.sh rimuove e ricrea dab-config.json utilizzando i comandi della CLI DAB. Eseguilo dopo aver modificato la sequenza dei comandi o quando vuoi ricostruire la configurazione da zero.

Per ripristinare i dati iniziali senza ricreare il container:

~~~bash
./reset.sh
~~~

Per rimuovere il container SQL Server e il relativo volume persistente:

~~~bash
docker compose down -v
~~~

## Nota sulla sicurezza

Questa è una configurazione locale di sviluppo con accesso non autenticato e permessi di scrittura sull’entità delle polizze. Non esporla a reti non fidate e non riutilizzarla come configurazione di produzione.

