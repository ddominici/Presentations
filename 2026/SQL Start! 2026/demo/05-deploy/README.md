# Deployment di DAB su Azure Container Instances

Questa demo inserisce una configurazione Data API builder in un’immagine container, la compila in remoto in Azure Container Registry (ACR), la esegue in Azure Container Instances (ACI) ed espone endpoint REST, GraphQL e MCP. Include anche un esempio di task definition AWS ECS; i file AWS sono un riferimento e non costituiscono un deployment automatizzato.

## Prerequisiti

- Azure CLI autenticata su una sottoscrizione in cui puoi creare resource group, ACR e ACI
- Provider di risorse Microsoft.ContainerRegistry e Microsoft.ContainerInstance abilitati
- Un database Azure SQL InsuranceDemo con gli oggetti usati dalla configurazione
- curl

La configurazione inclusa si aspetta DATABASE_CONNECTION_STRING. Lo script di deployment passa il valore di CONN tramite quella variabile d’ambiente. Non inserire credenziali in dab-config.json e non committare env.sh.

## Configurazione

Copia il file di esempio e modifica i valori:

~~~bash
cp env.sh.example env.sh
~~~

Imposta un nome ACR e un DNS label globalmente univoci, oltre a resource group, area, nome del container e stringa di connessione Azure SQL. env.sh è ignorato da Git.

## Deployment

Dalla cartella di questa demo:

~~~bash
./deploy-aci.sh
~~~

Lo script crea il resource group e il registry, compila l’immagine in Azure con az acr build, crea un’istanza ACI pubblica sulla porta 5000 e attende la risposta di /health. Al termine stampa il nome DNS completo (FQDN). Puoi usarlo così:

~~~bash
curl http://<fqdn>:5000/health
curl http://<fqdn>:5000/api/policies
~~~

Gli altri endpoint sono /api/openapi, /graphql e /mcp. Prima di usare gli esempi, sostituisci l’host in requests.http e mcp-client.json.

## Esempio di modalità produzione

Esegui promote-to-production.sh soltanto su un resource group usa-e-getta. Lo script imposta la modalità host su production, disabilita l’introspection GraphQL, compila una nuova immagine, elimina il container esistente e lo ricrea. L’eliminazione del container è intenzionale e lo script non esegue un deployment senza interruzioni.

## Limiti di sicurezza

L’esempio usa scorciatoie utili per una demo, ma da sostituire in produzione:

| Scorciatoia dell’esempio | Indicazione per la produzione |
|---|---|
| Credenziali amministrative ACR | Managed identity con ruolo AcrPull |
| Stringa di connessione come variabile d’ambiente | Managed identity o secret store come Key Vault |
| Endpoint ACI pubblico | Rete privata e gateway |
| Modalità sviluppo non autenticata | Autenticazione, privilegi minimi e impostazioni production |
| Tag immutabile non garantito | Tag dell’immagine verificato e fissato |

L’immagine contiene la configurazione DAB, ma non il valore della stringa di connessione. La configurazione pubblica e non autenticata non deve comunque essere usata con dati reali.

## Riferimento AWS

ecs-taskdef.json e aws-notes.md mostrano come descrivere lo stesso container per ECS. Sostituisci tutti i placeholder e prepara rete, registry e gestione dei segreti AWS prima di utilizzarli.

## Pulizia

Controlla il file env.sh, poi esegui:

~~~bash
./cleanup.sh
~~~

Il comando elimina l’intero resource group indicato da RG e tutte le risorse al suo interno.

