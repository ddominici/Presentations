#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

# Azure configuration
FILE=".env"
if [[ -f $FILE ]]; then
	echo "loading from .env"
    eval $(egrep "^[^#;]" $FILE | tr '\n' '\0' | xargs -0 -n1 | sed 's/^/export /')
else
	cat << EOF > .env
RESOURCE_GROUP='adroma24'
APP_NAME='dab-adroma24'
APP_PLAN_NAME='dab-plan-adroma24'
STORAGE_ACCOUNT='adroma24sa'
LOCATION='westeurope'
SQL_SERVER='sql-adroma24'
AZURE_SQL='Server=sql-adroma24.database.windows.net;Database=sqldb-adventureworks;User id=sqladmin;Password=71Cb8OIi95;TrustServerCertificate=True;'
EOF
	echo "Enviroment file (.env) not detected."
	echo "Please configure values for your environment in the created .env file and run the script again."
	exit 1
fi

IMAGE_NAME='mcr.microsoft.com/azure-databases/data-api-builder:latest'
DAB_CONFIG_FILE="dab-config.json"

echo "starting"
cat << EOF > log.txt
EOF

echo "creating resource group '$RESOURCE_GROUP'" | tee -a log.txt
az group create -g $RESOURCE_GROUP --location $LOCATION -o json >> log.txt


echo "creating sql server: '$SQL_SERVER'" | tee -a log.txt
az sql server create --name $SQL_SERVER --resource-group $RESOURCE_GROUP --admin-password "71Cb8OIi95" --admin-user "sqladmin"

az sql db create --name sqldb-adventureworks  --server $SQL_SERVER --resource-group $RESOURCE_GROUP --backup-storage-redundancy Local --edition Basic --capacity 5 --max-size 2GB --sample-name AdventureWorksLT

az sql server firewall-rule create --server $SQL_SERVER --resource-group $RESOURCE_GROUP --name AllowAzureServices --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0


echo "creating storage account: '$STORAGE_ACCOUNT'" | tee -a log.txt
az storage account create -n $STORAGE_ACCOUNT -g $RESOURCE_GROUP --allow-blob-public-access false --sku Standard_LRS -o json >> log.txt	

echo "retrieving storage connection string" | tee -a log.txt
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name $STORAGE_ACCOUNT -g $RESOURCE_GROUP -o tsv)

echo 'creating file share' | tee -a log.txt
az storage share create -n config --connection-string $STORAGE_CONNECTION_STRING -o json >> log.txt

echo "uploading configuration file '$DAB_CONFIG_FILE'" | tee -a log.txt
az storage file upload --share-name config --source $DAB_CONFIG_FILE --connection-string $STORAGE_CONNECTION_STRING -o json >> log.txt

echo "creating app plan '$APP_PLAN_NAME'" | tee -a log.txt
az appservice plan create -n $APP_PLAN_NAME -g $RESOURCE_GROUP --sku B1 --is-linux --location $LOCATION -o json >> log.txt

echo "retrieving app plan id" | tee -a log.txt
APP_PLAN_ID=$(az appservice plan show -g $RESOURCE_GROUP -n $APP_PLAN_NAME --query "id" --out tsv) 

echo "creating webapp '$APP_NAME'" | tee -a log.txt
az webapp create -g $RESOURCE_GROUP -p "$APP_PLAN_ID" -n $APP_NAME -i "$IMAGE_NAME" -o json >> log.txt

echo "retrieving storage key" | tee -a log.txt
asak=$(az storage account keys list -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT --query "[0].value" -o tsv)

echo "configure webapp storage-account" | tee -a log.txt
az webapp config storage-account add -g $RESOURCE_GROUP -n $APP_NAME --custom-id config --storage-type AzureFiles --share-name config --account-name $STORAGE_ACCOUNT --access-key "${asak}" --mount-path /App/config -o json >> log.txt

echo "configure webapp appsettings" | tee -a log.txt
az webapp config appsettings set -g $RESOURCE_GROUP -n $APP_NAME --settings WEBSITES_PORT=5000 -o json >> log.txt

echo "configure webapp appsettings" | tee -a log.txt
az webapp config appsettings set -g $RESOURCE_GROUP -n $APP_NAME --settings AZURE_SQL=$AZURE_SQL -o json >> log.txt

DAB_CONFIG_FILE_NAME=${DAB_CONFIG_FILE}
echo "updating webapp siteConfig to use $DAB_CONFIG_FILE_NAME" | tee -a log.txt
az webapp update -g $RESOURCE_GROUP -n $APP_NAME --set siteConfig.appCommandLine="dotnet Azure.DataApiBuilder.Service.dll --ConfigFileName /App/config/$DAB_CONFIG_FILE_NAME" -o json >> log.txt

echo "done" | tee -a log.txt
