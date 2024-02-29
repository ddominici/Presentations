/*
 * Piecemeal restore
 *
 * Richiede il backup del database MIcrosoft AdventureWorks2019
 * scaricabile qui: https://github.com/Microsoft/sql-server-samples/releases/tag/adventureworks
 *
 */

-- Restore iniziale
USE [master]
GO
ALTER DATABASE [AdventureWorks2019]
	SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
RESTORE DATABASE [AdventureWorks2019] 
	FROM DISK = 'C:\DataSat20\Demos\Backups\AdventureWorks2019.BAK' 
	WITH NORECOVERY, REPLACE;
GO
RESTORE DATABASE [AdventureWorks2019] 
	WITH RECOVERY;
GO
ALTER DATABASE [AdventureWorks2019] 
	SET RECOVERY FULL;
GO

USE AdventureWorks2019
GO

--
-- Getting some information about SalesOrderHeader table data distribution per year 
--

SELECT YEAR(OrderDate) AS Year, COUNT(*) AS No
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate)
ORDER BY YEAR(OrderDate)
GO

--
-- Setup Partitioning
--

-- Adding filegroups
ALTER DATABASE AdventureWorks2019 ADD FILEGROUP testfg1;
ALTER DATABASE AdventureWorks2019 ADD FILEGROUP testfg2;
ALTER DATABASE AdventureWorks2019 ADD FILEGROUP testfg3;
ALTER DATABASE AdventureWorks2019 ADD FILEGROUP testfg4;

-- Adding one file per filegroup
ALTER DATABASE AdventureWorks2019 ADD FILE (NAME='adv2019_fg1', FILENAME='C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\adv2019_fg1.ndf', SIZE=1MB, FILEGROWTH=100MB) TO FILEGROUP testfg1;
ALTER DATABASE AdventureWorks2019 ADD FILE (NAME='adv2019_fg2', FILENAME='C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\adv2019_fg2.ndf', SIZE=1MB, FILEGROWTH=100MB) TO FILEGROUP testfg2;
ALTER DATABASE AdventureWorks2019 ADD FILE (NAME='adv2019_fg3', FILENAME='C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\adv2019_fg3.ndf', SIZE=1MB, FILEGROWTH=100MB) TO FILEGROUP testfg3;
ALTER DATABASE AdventureWorks2019 ADD FILE (NAME='adv2019_fg4', FILENAME='C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\adv2019_fg4.ndf', SIZE=1MB, FILEGROWTH=100MB) TO FILEGROUP testfg4;

-- Create partition function (can be reused on multiple tables)
CREATE PARTITION FUNCTION pf_PartitionByDate (DATETIME)
AS RANGE RIGHT FOR VALUES ('20120101', '20130101', '20140101')
GO

-- Create partition scheme (can be reused on multiple tables)
CREATE PARTITION SCHEME ps_PartitionByDate  
AS PARTITION pf_PartitionByDate TO ( testfg1, testfg2, testfg3, testfg4 );  
	
/*
         -> 2011     2012       2013       2014 ->
       ----------+----------+----------+-----------
	       fg1       fg2        fg3        fg4
*/

-- Creating partitioned table
CREATE TABLE [dbo].[Orders]
(
	[SalesOrderID] [int] IDENTITY(1,1) NOT NULL,
	[RevisionNumber] [tinyint] NOT NULL,
	[OrderDate] [datetime] NOT NULL,
	[DueDate] [datetime] NOT NULL,
	[ShipDate] [datetime] NULL,
	[Status] [tinyint] NOT NULL,
	[OnlineOrderFlag] [dbo].[Flag] NOT NULL,
	[SalesOrderNumber] [nvarchar](25) NOT NULL,
	[PurchaseOrderNumber] [dbo].[OrderNumber] NULL,
	[AccountNumber] [dbo].[AccountNumber] NULL,
	[CustomerID] [int] NOT NULL,
	[SalesPersonID] [int] NULL,
	[TerritoryID] [int] NULL,
	[BillToAddressID] [int] NOT NULL,
	[ShipToAddressID] [int] NOT NULL,
	[ShipMethodID] [int] NOT NULL,
	[CreditCardID] [int] NULL,
	[CreditCardApprovalCode] [varchar](15) NULL,
	[CurrencyRateID] [int] NULL,
	[SubTotal] [money] NOT NULL,
	[TaxAmt] [money] NOT NULL,
	[Freight] [money] NOT NULL,
	[TotalDue] [money] NOT NULL,
	[Comment] [nvarchar](128) NULL,
	[rowguid] [uniqueidentifier] NOT NULL,
	[ModifiedDate] [datetime] NOT NULL,

	CONSTRAINT PK_Orders PRIMARY KEY NONCLUSTERED (SalesOrderID, OrderDate)
) 
ON ps_PartitionByDate(OrderDate)
GO

CREATE CLUSTERED INDEX CIX_Orders_OrderDate ON Orders (OrderDate) ON ps_PartitionByDate(OrderDate)
GO

SET IDENTITY_INSERT Orders ON
GO

INSERT INTO dbo.Orders 
(
	[SalesOrderID]
	,[RevisionNumber]
	,[OrderDate]
	,[DueDate]
	,[ShipDate]
	,[Status]
	,[OnlineOrderFlag]
	,[SalesOrderNumber]
	,[PurchaseOrderNumber]
	,[AccountNumber]
	,[CustomerID]
	,[SalesPersonID]
	,[TerritoryID]
	,[BillToAddressID]
	,[ShipToAddressID]
	,[ShipMethodID]
	,[CreditCardID]
	,[CreditCardApprovalCode]
	,[CurrencyRateID]
	,[SubTotal]
	,[TaxAmt]
	,[Freight]
	,[TotalDue]
	,[Comment]
	,[rowguid]
	,[ModifiedDate]
)
SELECT *
FROM Sales.SalesOrderHeader

SET IDENTITY_INSERT Orders OFF
GO

--
-- Partition statistics
--
CREATE PROC usp_GetPartitionInfo
AS
	SET NOCOUNT ON

	;WITH spc (data_space_id, function_id, boundary_id,
			  boundary_value_on_right, boundary_value)
	AS (    SELECT ps.data_space_id,
				val.function_id,
				val.boundary_id,
				pf.boundary_value_on_right,
				(CASE SQL_VARIANT_PROPERTY(val.[value], 'BaseType')
					WHEN 'date' THEN
						'{d '''+LEFT(CONVERT(varchar(max), val.[value], 120), 10)+'''}'
					WHEN 'datetime' THEN
						'{ts '''+CONVERT(varchar(max), val.[value], 120)+'''}'
					ELSE CAST(val.[value] AS varchar(max))
				 END) AS boundary_value
		FROM sys.partition_range_values AS val
		INNER JOIN sys.partition_functions AS pf ON
			val.function_id = pf.function_id
		INNER JOIN sys.partition_schemes AS ps ON
			pf.function_id=ps.function_id),

	--- Ranges, i.e. lower and upper bounds of a partition:
		 rng (function_id, data_space_id, boundary_id, lower_rng, upper_rng)
	AS (    SELECT ISNULL(a.function_id, b.function_id),
				ISNULL(a.data_space_id, b.data_space_id),
				ISNULL(a.boundary_id+1, b.boundary_id),
				a.boundary_value+(CASE
					WHEN a.boundary_value_on_right=1 THEN '<='
					WHEN a.boundary_value_on_right=0 THEN '<'
				 END) AS lower_rng,
				(CASE
					WHEN b.boundary_value_on_right=1 THEN '<'+b.boundary_value
					WHEN b.boundary_value_on_right=0 THEN '<='+b.boundary_value
				 END) AS upper_rng
		FROM spc AS a
		FULL JOIN spc AS b ON
			a.function_id=b.function_id AND
			a.boundary_id+1=b.boundary_id)

	--- ... joined with sys.indexes and sys.tables:
	SELECT p.[object_id],
		SCHEMA_NAME(t.[schema_id])+'.'+t.[name] AS [object_name],
		ix.index_id,
		ix.[name] AS index_name,
		pf.[name] AS pf_name,
		rng.boundary_id,
		ISNULL(rng.lower_rng, '')+'key'+ISNULL(rng.upper_rng, '') AS boundary,
		p.[rows],
		p.data_compression_desc
	FROM rng
	INNER JOIN sys.partition_functions AS pf ON
		rng.function_id = pf.function_id
	INNER JOIN sys.indexes AS ix ON
		ix.data_space_id=rng.data_space_id
	LEFT JOIN sys.tables AS t ON
		ix.[object_id]=t.[object_id]
	LEFT JOIN sys.partitions AS p ON
		ix.[object_id]=p.[object_id] AND
		ix.index_id=p.index_id AND
		rng.boundary_id=p.partition_number
	ORDER BY t.[schema_id], t.[name], p.index_id, rng.boundary_id;
GO

-- Show current partition stats
-- 2011 => 1607
-- 2012 => 3915
-- 2013 => 14182
-- 2014 => 11761
EXEC usp_GetPartitionInfo
GO

SELECT * FROM Orders


BACKUP DATABASE [AdventureWorks2019] 
	TO DISK = 'C:\DataSat20\Demos\Backups\Adv2019_Base_for_piecemeal.bak'
	WITH FORMAT, COMPRESSION;
GO

BACKUP DATABASE [AdventureWorks2019]
	FILEGROUP = 'PRIMARY',
	FILEGROUP = 'TESTFG1',
	FILEGROUP = 'TESTFG2',
	FILEGROUP = 'TESTFG3',
	FILEGROUP = 'TESTFG4'
	TO DISK = 'C:\DataSat20\Demos\Backups\Adv2019_Filegroups.bak'
	WITH FORMAT, COMPRESSION;
GO

--Restore only the primary file group.
USE [master];
GO

RESTORE FILELISTONLY FROM DISK = 'C:\DataSat20\Demos\Backups\Adv2019_Base_for_piecemeal.bak'

RESTORE DATABASE [AdventureWorks2019] 
	FILEGROUP = 'PRIMARY', 
	FILEGROUP = 'testfg1'
	FROM DISK = 'C:\DataSat20\Demos\Backups\Adv2019_Base_for_piecemeal.bak' 
	WITH PARTIAL, RECOVERY, REPLACE;
GO

--Show that only the primary file group and the transaction log are online.
SELECT name, state_desc FROM [AdventureWorks2019].sys.database_files;
GO

--Can now view information in the online filegroups
SELECT OrderDate
FROM [AdventureWorks2019].dbo.Orders 
WHERE orderdate BETWEEN '2011-01-01' AND '2011-12-31';
GO

-- Other filegroups won't work!
SELECT OrderDate
FROM [AdventureWorks2019].dbo.Orders 
WHERE orderdate BETWEEN '2012-01-01' AND '2012-12-31';
GO

--Restore Other File Groups
RESTORE DATABASE [AdventureWorks2019] FILEGROUP = 'testfg2' WITH RECOVERY;
GO
RESTORE DATABASE [AdventureWorks2019] FILEGROUP = 'testfg3' WITH RECOVERY;
GO
RESTORE DATABASE [AdventureWorks2019] FILEGROUP = 'testfg4' WITH RECOVERY;
GO

--View State
SELECT name, state_desc FROM [AdventureWorks2019].sys.database_files;
GO

SELECT YEAR(OrderDate) AS YY, COUNT(*) AS cnt
FROM [AdventureWorks2019].dbo.Orders 
GROUP BY YEAR(OrderDate)
GO

-- EOF