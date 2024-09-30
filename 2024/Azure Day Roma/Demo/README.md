# Demos for Data API Builder session

Last updated: 2024-06-21

Follow these steps for an exercise to see how it works Data API Builder.

## Prerequisites

- .NET Core 6

If you don't have .NET Core 6 SDK, you can install from here: https://dotnet.microsoft.com/download/dotnet/6.0

## Installation

dotnet tool install -g Microsoft.DataApiBuilder

Current version (2024-06-20) is 1.1.7.

If you experiencing some problem in installing DAB, try

dotnet tool install -g --add-source 'https://api.nuget.org/v3/index.json' --ignore-failed-sources Microsoft.DataApiBuilder


## Configuration

dab init --database-type "mssql" --connection-string "Server=localhost;Database=adventureworksLT2019;User ID=dab-reader;Password=&uyTe87!ttu3;TrustServerCertificate=true" --host-mode "Development"

dab add customer --source SalesLT.Customer --permissions "anonymous:*"

dab add order --source SalesLT.OrderHeader --permissions "anonymous:*"

dab add product --source SalesLT.Product --permissions "anonymous:*"

dab start

## GraphQL basics

### Semplice query per elencare nome e città per tutti i clienti

{
  customers() {
    items {
      CompanyName,
      City
    }
  }
}

### Semplice query per visualizzare i dati del cliente ed i relativi ordini

{
  customers(filter: { CustomerID: { contains: "ALFKI" } }) {
    items {
      CompanyName,
      City,
      orders() {
        items{
          OrderID,
          OrderDate
        }
      }
    }
  }
}


## Demo Power BI

### Query per estrarre i clienti per nazione
let
    uri = "https://localhost:5001/graphql",
    query = "{ customers() { items { CompanyName, Country } } }",
    source = uri & "?query=" & Uri.EscapeDataString(query),
    resp = Json.Document(Web.Contents(source)),
    data = resp[data],
    customers = data[customers],
    #"Conversione in tabella" = Record.ToTable(customers),
    #"Tabella Value espansa" = Table.ExpandListColumn(#"Conversione in tabella", "Value"),
    #"Tabella Value espansa1" = Table.ExpandRecordColumn(#"Tabella Value espansa", "Value", {"CompanyName", "Country"}, {"Value.CompanyName", "Value.Country"}),
    #"Rimosse colonne" = Table.RemoveColumns(#"Tabella Value espansa1",{"Name"}),
    #"Rinominate colonne" = Table.RenameColumns(#"Rimosse colonne",{{"Value.CompanyName", "CompanyName"}, {"Value.Country", "Country"}})
in
    #"Rinominate colonne"
	
### Query per estrarre solo i clienti USA per città
let
    uri = "https://localhost:5001/graphql",
    query = "{ customers(filter: { Country: { eq: ""USA"" } } ) { items { CompanyName, City } } }",
    source = uri & "?query=" & Uri.EscapeDataString(query),
    resp = Json.Document(Web.Contents(source)),
    data = resp[data],
    customers = data[customers],
    #"Conversione in tabella" = Record.ToTable(customers),
    #"Tabella Value espansa" = Table.ExpandListColumn(#"Conversione in tabella", "Value"),
    #"Tabella Value espansa1" = Table.ExpandRecordColumn(#"Tabella Value espansa", "Value", {"CompanyName", "City"}, {"Value.CompanyName", "Value.City"}),
    #"Rimosse colonne" = Table.RemoveColumns(#"Tabella Value espansa1",{"Name"}),
    #"Rinominate colonne" = Table.RenameColumns(#"Rimosse colonne",{{"Value.CompanyName", "CompanyName"}, {"Value.City", "City"}})
in
    #"Rinominate colonne"
	

## Resources

Data API Builder official pages
https://learn.microsoft.com/en-us/azure/data-api-builder/overview-to-data-api-builder?tabs=azure-sql

Source code
https://github.com/Azure/data-api-builder

Davide's code
https://github.com/Azure-Samples/data-api-builder/tree/main

Microsoft Registry container image
https://mcr.microsoft.com/en-us/product/azure-databases/data-api-builder/tags

NuGet package
https://www.nuget.org/packages/Microsoft.DataApiBuilder#versions-body-tab

GraphQL
https://graphql.org/learn/

