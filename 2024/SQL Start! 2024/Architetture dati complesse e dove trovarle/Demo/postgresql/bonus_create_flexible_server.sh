az account set --subscription 4708c8e5-b317-4edd-bc2b-3c5a6def23ed

az group create --name sqlstart2024 --location northeurope

az postgres flexible-server create --name sqlstart2024 --resource-group sqlstart2024 --admin-user pgadmin --admin-password P@ssw0rd! --sku-name Standard_B1ms --tier Burstable --version 16 --high-availability Disabled
