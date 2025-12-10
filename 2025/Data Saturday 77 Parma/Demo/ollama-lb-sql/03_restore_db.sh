#!/bin/bash

# Copy the MDF and LDF files to the SQL Server container
docker cp ./backups/AdventureWorks2022.bak sql-server:/var/opt/mssql/data/ &

sleep 10 

# Change ownership of the files to the mssql user
docker exec -it -u 0 sql-server chown mssql:mssql /var/opt/mssql/data/AdventureWorks2022.bak

# Use docker exec to launch sqlcmd inside the SQL Server container to attach the databases and trust the certificate
docker exec -it sql-server /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'S0methingS@Str0ng!' -C -d master -Q \
  "RESTORE DATABASE [AdventureWorks] FROM DISK = N'/var/opt/mssql/data/AdventureWorks2022.bak' WITH  
FILE = 1,  MOVE N'AdventureWorks2022' TO N'/var/opt/mssql/data/AdventureWorks.mdf',  
MOVE N'AdventureWorks2022_log' TO N'/var/opt/mssql/data/AdventureWorks_log.ldf',  
REPLACE, NOUNLOAD;"

# Head over to vector-demos.sql and run the SQL script to generate vector embeddings for all posts in the StackOverflow_Embeddings_Small database
echo "Database restored successfully."
