# Setup progetto

### Parametri di configurazione
$resourceGroupName = "RG-XMASDEV24"
$location = "westeurope"
$appServicePlanName = "SantaDeliveryAppPlan"
$apiAppName = "SantaDeliveryApiDD"
$blazorAppName = "SantaDeliveryAppDD"
$sqlServerName = "SantaDeliverySql"
$sqlDatabaseName = "SantaDelivery"
$sqlAdminUser = "xmasdev-admin"
$sqlAdminPassword = "Pa$$w0rd!?!"

### Creazione del gruppo di risorse
az group create --name $resourceGroupName --location $location

### Creazione del piano App Service
Write-Host "Creazione del piano App Service: $appServicePlanName"
az appservice plan create --name $appServicePlanName --resource-group $resourceGroupName --sku B1 --location $location

### Creazione dell'App Service per le API
Write-Host "Creazione dell'App Service per le API: $apiAppName"
az webapp create --name $apiAppName --resource-group $resourceGroupName --plan $appServicePlanName --runtime "DOTNET:6"

### Creazione dell'App Service per il sito Blazor
Write-Host "Creazione dell'App Service per il sito Blazor: $blazorAppName"
az webapp create --name $blazorAppName --resource-group $resourceGroupName --plan $appServicePlanName --runtime "DOTNET:6"

### Creazione del server SQL
Write-Host "Creazione del server SQL: $sqlServerName"
az sql server create --name $sqlServerName --resource-group $resourceGroupName --location $location --admin-user $sqlAdminUser --admin-password $sqlAdminPassword

### Creazione del database SQL
Write-Host "Creazione del database SQL: $sqlDatabaseName"
az sql db create --name $sqlDatabaseName --resource-group $resourceGroupName --server $sqlServerName --service-objective S0

### Configurazione del firewall per consentire l'accesso locale al server SQL
Write-Host "Configurazione del firewall per il server SQL"
$myIp = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content.Trim()
az sql server firewall-rule create --resource-group $resourceGroupName --server $sqlServerName --name "AllowMyIP" --start-ip-address $myIp --end-ip-address $myIp

# Configurazione della stringa di connessione nelle impostazioni dell'App Service (API)
Write-Host "Configurazione della stringa di connessione per l'App Service delle API"
$sqlConnectionString = "Server=tcp:$sqlServerName.database.windows.net,1433;Initial Catalog=$sqlDatabaseName;Persist Security Info=False;User ID=$sqlAdminUser;Password=$sqlAdminPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
az webapp config connection-string set --name $apiAppName --resource-group $resourceGroupName --settings "DefaultConnection=$sqlConnectionString" --connection-string-type SQLAzure

# Configurazione delle impostazioni del Blazor site per puntare all'API
Write-Host "Configurazione dell'URL API nell'App Service Blazor"
$apiUrl = "https://$apiAppName.azurewebsites.net"
az webapp config appsettings set --name $blazorAppName --resource-group $resourceGroupName --settings "ApiBaseUrl=$apiUrl"

# Forzare HTTPS per entrambi gli App Services
Write-Host "Abilitazione di HTTPS obbligatorio sugli App Services"
az webapp update --name $apiAppName --resource-group $resourceGroupName --set httpsOnly=true
az webapp update --name $blazorAppName --resource-group $resourceGroupName --set httpsOnly=true

Write-Host "Tutti i servizi sono stati creati con successo!"
