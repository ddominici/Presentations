/*

CREATE TABLE Deliveries (
    Id INT PRIMARY KEY IDENTITY(1,1),
    FirstName NVARCHAR(100),
    LastName NVARCHAR(100),
    Region NVARCHAR(100),
    Latitude FLOAT,
    Longitude FLOAT,
    DeliveryTime DATETIME,
    EventProcessedUtcTime DATETIME2,
    PartitionId INT
);

-- Read-only user
CREATE USER deliveryuser WITH PASSWORD='vitvoc-bamja3-seJtoj'
EXEC sp_addrolemember 'db_datareader', 'deliveryuser';

-- Read-write user
CREATE USER deliveryagent WITH PASSWORD='vitvoc-bamja3-seJtoj'

EXEC sp_addrolemember 'db_datawriter', 'deliveryagent';
EXEC sp_addrolemember 'db_datareader', 'deliveryagent';

*/

SELECT * FROM deliveries;