/*
 * Backup Strategy #2 - FULL + DIFF + LOG - Using Ola Hallengren's Maintenance Solution
 *
 *
 */

-- RESTORE AdventureWorks2019 from our base backup.
USE [master]
GO
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


--Clear backup history just in case I have ran this demo before.
DECLARE @DATE DATETIME
SET @DATE = GETDATE()+1
EXEC msdb.dbo.sp_delete_backuphistory @DATE;
GO

IF OBJECT_ID('msdb.dbo.CommandLog') IS NOT NULL
TRUNCATE TABLE msdb.dbo.CommandLog


-- Show the top 10 orders by SalesOrderID DESC
-- This will allow us to see when we insert new records
USE [AdventureWorks2019];
GO
SELECT TOP 10 * 
FROM Sales.SalesOrderDetail
ORDER BY SalesOrderID DESC;
GO

-- Backup the database and log 
EXECUTE msdb.dbo.DatabaseBackup
	@Databases = 'AdventureWorks2019',
	@Directory = 'C:\DataSat20\Demos\Backups',
	@BackupType = 'FULL',
	@Verify = 'Y',
	@Compress = 'Y',
	@CheckSum = 'Y',
	@CleanupTime = 24,
	@LogToTable = 'Y';

EXECUTE msdb.dbo.DatabaseBackup
	@Databases = 'AdventureWorks2019',
	@Directory = 'C:\DataSat20\Demos\Backups',
	@Compress = 'Y',
	@BackupType = 'LOG',
	@LogToTable = 'Y';

-- Update some records
UPDATE Sales.SalesOrderDetail
SET CarrierTrackingNumber = '20220226-DD-001'
WHERE SalesOrderID = 75123
GO

SELECT TOP 10 * 
FROM Sales.SalesOrderDetail
ORDER BY SalesOrderID DESC;
GO

--Backup the log 
EXECUTE msdb.dbo.DatabaseBackup
	@Databases = 'AdventureWorks2019',
	@Directory = 'C:\DataSat20\Demos\Backups',
	@Compress = 'Y',
	@BackupType = 'LOG',
	@LogToTable = 'Y';

-- Update all records
UPDATE TOP (100) Sales.SalesOrderDetail
SET UnitPriceDiscount = 0.10
GO

SELECT TOP 10 * 
FROM Sales.SalesOrderDetail
ORDER BY SalesOrderID DESC;
GO

--Backup database (differential) 
EXECUTE msdb.dbo.DatabaseBackup
	@Databases = 'AdventureWorks2019',
	@Directory = 'C:\DataSat20\Demos\Backups',
	@BackupType = 'DIFF',
	@Verify = 'Y',
	@Compress = 'Y',
	@CheckSum = 'Y',
	@CleanupTime = 24,
	@LogToTable = 'Y';

-- Update some records
UPDATE Sales.SalesOrderDetail
SET CarrierTrackingNumber = '20220226-DD-002'
WHERE SalesOrderID = 75121
GO

SELECT TOP 10 * 
FROM Sales.SalesOrderDetail
ORDER BY SalesOrderID DESC;
GO

--Backup the log 
EXECUTE msdb.dbo.DatabaseBackup
	@Databases = 'AdventureWorks2019',
	@Directory = 'C:\DataSat20\Demos\Backups',
	@Compress = 'Y',
	@BackupType = 'LOG',
	@LogToTable = 'Y';

/* I'm still able to retrieve all the required files to fully restore the database */

DECLARE @databaseName sysname
DECLARE @backupStartDate datetime
DECLARE @backup_set_id_start INT
DECLARE @backup_set_id_FULL INT
DECLARE @backup_set_id_end INT

-- set database to be used
SET @databaseName = 'AdventureWorks2019' 

SELECT @backup_set_id_FULL = MAX(backup_set_id) 
	FROM  msdb.dbo.backupset 
	WHERE database_name = @databaseName AND type = 'D'

SELECT @backup_set_id_start = MAX(backup_set_id) 
	FROM  msdb.dbo.backupset 
	WHERE database_name = @databaseName AND type = 'I'

SELECT @backup_set_id_end = MIN(backup_set_id) 
	FROM  msdb.dbo.backupset 
	WHERE database_name = @databaseName AND type = 'D'
	AND backup_set_id > @backup_set_id_start

IF @backup_set_id_end IS NULL SET @backup_set_id_end = 999999999

SELECT backup_set_id, 'RESTORE DATABASE ' + @databaseName + ' FROM DISK = ''' 
               + mf.physical_device_name + ''' WITH NORECOVERY'
	FROM msdb.dbo.backupset b,
         msdb.dbo.backupmediafamily mf
	WHERE b.media_set_id = mf.media_set_id
			AND b.database_name = @databaseName
			AND b.backup_set_id = @backup_set_id_FULL
UNION
SELECT backup_set_id, 'RESTORE DATABASE ' + @databaseName + ' FROM DISK = ''' 
            + mf.physical_device_name + ''' WITH NORECOVERY'
	FROM    msdb.dbo.backupset b,
			msdb.dbo.backupmediafamily mf
	WHERE   b.media_set_id = mf.media_set_id
			AND b.database_name = @databaseName
			AND b.backup_set_id = @backup_set_id_start
UNION
SELECT backup_set_id, 'RESTORE LOG ' + @databaseName + ' FROM DISK = ''' 
         + mf.physical_device_name + ''' WITH NORECOVERY'
	FROM	msdb.dbo.backupset b,
			msdb.dbo.backupmediafamily mf
	WHERE b.media_set_id = mf.media_set_id
			AND b.database_name = @databaseName
			AND b.backup_set_id >= @backup_set_id_start AND b.backup_set_id < @backup_set_id_end
			AND b.type = 'L'
UNION
SELECT 999999999 AS backup_set_id, 'RESTORE DATABASE ' + @databaseName + ' WITH RECOVERY'
ORDER BY backup_set_id;