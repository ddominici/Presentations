az login

az account set --subscription "4708c8e5-b317-4edd-bc2b-3c5a6def23ed"

az postgres flexible-server create --location westeurope --resource-group "RG-DD-POSTGRESQL"  \
  --name ddpgsql02 --admin-user danilo  --admin-password "P@ssw0rd!"  \
  --sku-name Standard_B1ms --tier Burstable --storage-size 128 \
  --tags "location=Pordenone" --version 13 --high-availability Disabled

az postgres server create -l westeurope -g "RG-DD-POSTGRESQL" -n pgdd02 -u danilo -p "P@ssw0rd!" \
    --sku-name B_Gen5_1 --ssl-enforcement Enabled --minimal-tls-version TLS1_0 --public-network-access Disabled \
    --backup-retention 10 --geo-redundant-backup Enabled --storage-size 51200 \
    --tags "location=Pordenone" --version 11
