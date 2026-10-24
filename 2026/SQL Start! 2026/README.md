# Data API Builder 2.0 — demo SQL Start

Questa cartella contiene esempi eseguibili per pubblicare dati SQL Server, PostgreSQL, Azure SQL e Microsoft Fabric tramite Data API builder (DAB), utilizzando endpoint REST, GraphQL e MCP.

## Mappa delle demo

| Cartella | Contenuto |
|---|---|
| [demo/01-onprem](demo/01-onprem/) | SQL Server locale in Docker, REST, GraphQL, una vista, una stored procedure e MCP |
| [demo/01a-onprem-pg](demo/01a-onprem-pg/) | Alternativa PostgreSQL alla demo SQL Server locale |
| [demo/02-azuresql](demo/02-azuresql/) | Sicurezza su Azure SQL e caching delle risposte |
| [demo/03-fabric-multisource](demo/03-fabric-multisource/) | Un’unica API su SQL Server locale, Azure SQL e Fabric SQL |
| [demo/04-mcp](demo/04-mcp/) | Tool MCP in sola lettura e client React |
| [demo/05-deploy](demo/05-deploy/) | Deployment su Azure Container Instances e riferimento AWS ECS |

Inizia da [demo/01-onprem/README.md](demo/01-onprem/README.md). La demo PostgreSQL è un’alternativa e non è prerequisita per le altre.

## Requisiti

- Data API builder CLI 2.0.x
- Docker Desktop per la demo SQL Server locale
- PostgreSQL per la demo 01a
- Node.js e npm per le web app
- Azure CLI per gli esempi Azure SQL, Fabric e deployment
- curl; per i file .http è utile l’estensione VS Code REST Client

## Configurazione condivisa

Copia il modello delle variabili d’ambiente e modifica i valori necessari:

~~~bash
cp .env.example .env
~~~

Il file .env è ignorato da Git. Contiene esempi di stringhe di connessione per SQL Server locale, Azure SQL e Fabric. La demo 01a richiede inoltre PG_CONN; consulta il relativo README.

La demo di deployment usa un file separato:

~~~bash
cd demo/05-deploy
cp env.sh.example env.sh
~~~

Non inserire credenziali nel repository. In un deployment reale preferisci una managed identity o un sistema di gestione dei segreti.

## Dipendenze tra le demo

La demo 1 crea lo schema InsuranceDemo e i dati iniziali in Docker. La demo 3 riutilizza il database SQL Server locale, i dati Azure SQL della demo 2 e gli oggetti Fabric creati dal relativo script SQL. La demo 4 riutilizza il database SQL Server locale della demo 1. La demo 01a è indipendente e usa un database PostgreSQL già esistente.

Esegui una sola istanza DAB alla volta perché gli esempi usano la porta 5000. Le web app opzionali usano Vite sulle porte 5173, 5174 e 5175; i relativi README contengono i comandi di avvio.

## Sicurezza

Le configurazioni di esempio sono pensate per lo sviluppo locale e utilizzano spesso accesso non autenticato. Prima di usarle con dati reali configura autenticazione, privilegi minimi e accesso di rete limitato.

