# Azure SQL: autenticazione, autorizzazione e cache

Questa demo collega DAB a un database Azure SQL e mostra tre livelli indipendenti di sicurezza: autenticazione Microsoft Entra, permessi a livello di campo e policy a livello di riga. Abilita inoltre la cache delle risposte DAB.

## Prerequisiti

- Un database Azure SQL denominato InsuranceDemo
- Data API builder CLI 2.0.x (dab)
- Un metodo di autenticazione supportato dall’ambiente in cui viene eseguito DAB
- Azure CLI o un altro client SQL per eseguire gli script del database

## Preparazione di Azure SQL

1. Crea il database ed esegui sql/01-schema-azuresql.sql.
2. Aggiungi AZURE_SQL_CONN al file ../../.env. L’esempio usa l’autenticazione Microsoft Entra; quando DAB viene eseguito in Azure preferisci una managed identity, mentre per lo sviluppo locale puoi usare Active Directory Default.
3. Se vuoi configurare i ruoli Entra, segui entra-setup.md. Imposta ENTRA_TENANT_ID e ENTRA_AUDIENCE, crea i ruoli applicativi ed esegui sql/02-entra-mapping.sql con l’object ID dell’utente broker.
4. Esegui sql/03-optional-rls.sql solo se vuoi combinare le policy DAB con la sicurezza a livello di riga del database.

## Avvio

Dalla cartella di questa demo:

~~~bash
./run.sh
~~~

Lo script ricrea la configurazione, la valida, mostra i permessi effettivi e avvia DAB sulla porta 5000. Per esaminare la configurazione senza avviare il servizio:

~~~bash
./build-config.sh
dab validate
dab configure --show-effective-permissions
~~~

## Comportamento predefinito

Il builder incluso lascia commentati i comandi per autenticazione e autorizzazione Entra. Una nuova esecuzione usa quindi accesso Unauthenticated e permessi anonymous. Questo rende la demo eseguibile, ma non è una configurazione sicura per un endpoint condiviso o pubblico.

Per abilitare il percorso di sicurezza, adatta e decommenta i comandi pertinenti in build-config.sh, poi ricrea e valida la configurazione. Gli esempi utilizzano:

- ruoli applicativi reader e broker, letti dal claim roles del token;
- esclusioni di campi sensibili come commission_amount e broker_oid;
- una policy che confronta @item.broker_oid con @claims.oid;
- un ruolo admin con permessi più ampi.

Con --set-session-context true DAB può trasferire i claim in SQL Server SESSION_CONTEXT, permettendo allo script opzionale RLS del database di applicare la stessa identità a livello SQL.

## Endpoint API

| URL | Scopo |
|---|---|
| http://localhost:5000/health | Stato del servizio |
| http://localhost:5000/api/openapi | Documento OpenAPI e Swagger UI |
| http://localhost:5000/api/policies | Polizze |
| http://localhost:5000/api/brokers | Broker |
| http://localhost:5000/api/claims | Sinistri |
| http://localhost:5000/graphql | Endpoint GraphQL |
| http://localhost:5000/mcp | Endpoint MCP |

Quando abiliti i permessi per ruolo, invia alle richieste un bearer token valido e confronta le risposte dati o i documenti OpenAPI prodotti per ciascun ruolo. requests.http contiene esempi per le richieste locali; non inserire mai token reali nel repository.

## Esempio di cache

Il builder abilita una cache globale di 30 secondi e una cache L1 per Policy. sql/04-cache-proof.sql contiene le query per esaminare i contatori relativi alla cache. Le scritture eseguite fuori da DAB non invalidano la cache DAB; scegli quindi con attenzione il TTL. L’autenticazione delegata dell’utente (On-Behalf-Of) non dovrebbe essere combinata con la cache; consulta l’ultima sezione di entra-setup.md.

## Nota sulla sicurezza

L’esempio è destinato allo sviluppo. Usa una managed identity o un sistema di gestione dei segreti per la connessione al database, configura autenticazione e privilegi minimi e non esporre la configurazione predefinita non autenticata.

