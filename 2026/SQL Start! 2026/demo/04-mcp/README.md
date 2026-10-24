# Client MCP in sola lettura

Questa demo è una piccola applicazione React e TypeScript che utilizza l’endpoint MCP HTTP streamable di Data API builder. Scopre i tool disponibili, converte alcune domande di esempio in chiamate tipizzate read_records o aggregate_records e visualizza i risultati.

L’applicazione browser non utilizza un modello linguistico e non converte testo libero arbitrario in SQL. Il planner locale è deterministico e serve a mostrare il flusso MCP lato client.

## Prerequisiti

- Il database SQL Server locale della demo ../01-onprem/
- Data API builder CLI 2.0.x (dab)
- Node.js e npm

## Avvio

Avvia DAB in un terminale:

~~~bash
./run.sh
~~~

Poi, dalla cartella di questa demo, avvia la web app in un secondo terminale:

~~~bash
npm install
npm run dev
~~~

Apri http://localhost:5175. Vite inoltra /mcp e /health a DAB su http://localhost:5000, quindi il browser rimane sulla stessa origine e nessuna credenziale del database viene inviata al client.

## Tool esposti dalla configurazione

dab-config.json abilita questi tool MCP DML in sola lettura:

- describe_entities, inclusi descrizioni dei campi e metadati delle chiavi primarie;
- read_records;
- aggregate_records.

I tool di creazione, aggiornamento, eliminazione ed esecuzione delle entità sono disabilitati. La stessa configurazione espone anche endpoint REST, GraphQL e health sulla porta 5000.

L’interfaccia usa le entità Policy, Broker e PolicySummary del database locale popolato con i dati di esempio. Le descrizioni dei campi sono esplicite affinché un consumer MCP riceva metadati comprensibili dal punto di vista del dominio, invece dei soli identificatori del database.

## Nota sulla sicurezza

La configurazione DAB usa accesso non autenticato in modalità sviluppo ed è destinata all’uso locale. Non pubblicare l’endpoint senza autenticazione, limitazione delle origini consentite e revisione dei tool esposti tramite MCP.

