# Create Azure Group
az group create --location westeurope --name 1nn0va

# Create Azure SQL Database
az sql server create --name sql-1nn0va --resource-group 1nn0va --admin-password "71Cb8OIi95" --admin-user "sqladmin"

# Restore AdventureWorksLT
az sql db create --name sqldb-adventureworks --resource-group 1nn0va --server sql-1nn0va --backup-storage-redundancy Local --edition Basic --capacity 5 --max-size 2GB --sample-name AdventureWorksLT

# Configure firewall to allow Azure Services
az sql server firewall-rule create --server sql-1nn0va --resource-group 1nn0va --name AllowAzureServices --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

# Create storage account 
az storage account create --name 1nn0vadabdemo --resource-group 1nn0va --location westeurope

# Create file shares
az storage share create --name dab-config --account-name 1nn0vadabdemo
  
az storage share create --name proxy-caddyfile --account-name 1nn0vadabdemo

az storage share create --name proxy-config --account-name 1nn0vadabdemo
  
az storage share create --name proxy-data --account-name 1nn0vadabdemo

#
# Retrieve Blob Storage Access Key and Database connection string (needed to fill the required fields in .yaml config file)
#
az storage account show-connection-string --name 1nn0vadabdemo --resource-group 1nn0va

az storage account keys list --resource-group 1nn0va --account-name 1nn0vadabdemo --query [0].value --output tsv

az sql db show-connection-string --client ado.net --name sqldb-adventureworks --server sql-1nn0va --output tsv 

# Create ACI
az container create --resource-group 1nn0va --file ci-adventureworkslt-api.yaml

# Open browser and point to 
#   https://1nn0va-dab-api-demo.westeurope.azurecontainer.io/api/product/ProductID/680
# or 
#   https://1nn0va-dab-api-demo.westeurope.azurecontainer.io/api/product

