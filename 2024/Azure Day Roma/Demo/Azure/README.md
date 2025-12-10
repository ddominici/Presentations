# Istruzioni per l'uso

La demo del Data API Builder utilizza una serie di servizi:
- Azure SQL Database server (adroma24sql) su cui è presente il database demo AdventureWorksLT
- Storage account per contenere la file share di configurazione del DAB
- App Service Plan B1
- App Service che contiene il DAB

Per inizializzare tutti i servizi:

<ul>
<li>installare il [client Azure](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)</li>
<li>effettuare il login con il comando <strong>az login</strong></li>
<li>eseguire il file init.sh</li>
Nel caso in cui sia la prima volta che viene eseguito e non è presente il file .env contenente tutti i parametri per la creazione dei servizi Azure, eseguire una seconda volta il file init.sh.
</ul>

L'esito dei vari comandi viene scritto nel file log.txt, utile nel caso in cui ci siano errori nella creazione dei servizi Azure.

> ATTENZIONE !!! Alcuni dei servizi Azure installati sono a pagamento (SQL Server e App Service Plan), al costo di poche decine di Euro/mese, ma si consiglia di rimuovere tutti i servizi dopo aver sperimentato la demo, eliminando il gruppo <strong>adroma24</strong>

## Usare Data API Builder

Per testare il funzionamento del Data API Builder è sufficiente aprire il browser ed utilizzare uno dei seguenti URL:

Verifica dello stato del servizio: https://dab-adroma24.azurewebsites.net Se tutto funziona risponde <strong>Healthy</strong>

[Swagger](https://dab-adroma24.azurewebsites.net/swagger)

[GraphQL](https://dab-adroma24.azurewebsites.net/graphql)

### Esempi

#### REST

Elenco dei prodotti
https://dab-adroma24.azurewebsites.net/api/product

#### GraphQL

Aprire il client [GraphQL](https://dab-adroma24.azurewebsites.net/graphql), creare un nuovo documento se non ne esiste già uno, ed utilizzare le seguenti query di esempio:

`
{
  products
  {
    items {
      Name, Color, ListPrice
    }
    hasNextPage
    endCursor
  }
}
`

`
{
  products(filter: { Color: { contains: "Red" } })
  {
    items {
      Name, Color, ListPrice
    }
    hasNextPage
    endCursor
  }
}
`

Altri esempi di query GraphQL: https://learn.microsoft.com/en-us/azure/data-api-builder/graphql

