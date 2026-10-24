# API multi-sorgente con SQL Server, Azure SQL e Fabric

Questa demo esegue un unico processo Data API builder su tre database e li espone tramite una sola base URL e un unico documento OpenAPI. L’API aggrega la configurazione, non i dati: DAB non esegue join o query distribuite tra le diverse sorgenti.

## Prerequisiti

- Data API builder CLI 2.0.x (dab)
- Il database SQL Server locale della demo ../01-onprem/
- Il database Azure SQL e la tabella Claim della demo ../02-azuresql/
- Un database SQL in Microsoft Fabric denominato SalesDemo
- Credenziali Microsoft Entra per la connessione Fabric

Prima dell’avvio esegui sql/01-fabric-salesfact.sql nell’editor di query Fabric. Fabric SQL non accetta login SQL.

Imposta SQL_CONN, AZURE_SQL_CONN e FABRIC_CONN in ../../.env. Le stringhe di connessione vengono risolte a runtime tramite @env(...) e non sono inserite nei file di configurazione.

## Avvio

Dalla cartella di questa demo:

~~~bash
./run.sh
~~~

Lo script controlla le tre variabili di connessione, valida la configurazione combinata e avvia DAB sulla porta 5000.

## Endpoint API

| URL | Sorgente dati |
|---|---|
| /api/policies | SQL Server locale |
| /api/brokers | SQL Server locale |
| /api/claims | Azure SQL |
| /api/sales-fact | SQL database in Fabric |
| /api/sales-by-region | Vista Fabric |
| /api/openapi | Documento OpenAPI combinato |
| /health | Stato del runtime e delle sorgenti nominate |
| /graphql | Endpoint GraphQL combinato |
| /mcp | Endpoint MCP |

Il client React opzionale è descritto in webapp/README.md.

## File di configurazione

| File | Contenuto |
|---|---|
| dab-config.json | Runtime principale e sorgente SQL Server locale |
| dab-config.azuresql.json | Sorgente Azure SQL ed entità Claim |
| dab-config.fabric.json | Sorgente Fabric, entità SalesFact e SalesByRegion |
| run.sh | Controllo dell’ambiente, validazione e avvio |

I file figli devono contenere le proprie sezioni data-source ed entities. Le impostazioni runtime provengono dal file principale. Mantieni univoci i nomi delle entità e i percorsi REST nell’insieme dei file.

## Varianti Fabric

La configurazione inclusa usa un database SQL in Fabric con database-type: mssql. Un Fabric Warehouse o un endpoint SQL analitico di un Lakehouse richiede dettagli di connessione diversi e potrebbe usare database-type: dwsql; verifica le funzionalità DAB supportate prima di adattare la configurazione figlia.

## Limiti e sicurezza

L’esempio usa accesso non autenticato in modalità sviluppo. Configura autenticazione e privilegi minimi prima di esporre una qualsiasi sorgente. Se Fabric non è disponibile, rimuovi la configurazione figlia e le relative entità e modifica run.sh per non richiedere FABRIC_CONN prima di usare le due sorgenti rimanenti.

