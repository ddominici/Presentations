/*
 * 'Tail log' backup
 *
 * Richiede il backup del database Microsoft AdventureWorks2019
 * scaricabile qui: https://github.com/Microsoft/sql-server-samples/releases/tag/adventureworks
 *
 */

-- RESTORE AdventureWorks2019 from our base backup.
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

BACKUP DATABASE [AdventureWorks2019]
	TO DISK = 'C:\DataSat20\Demos\Backups\Adv2019_Base.BAK'
	WITH FORMAT, COMPRESSION;
GO

USE [AdventureWorks2019]
GO

SELECT COUNT(*) AS BlackProductsBeforeUpdate FROM Production.Product WHERE Color IS NULL;
GO

UPDATE Production.Product SET Color = 'Black' WHERE Color IS NULL;
GO

SELECT COUNT(*) BlackProductsAfterUpdate FROM Production.Product WHERE Color ='Black';
GO

USE MASTER;
GO

ALTER DATABASE [AdventureWorks2019] SET OFFLINE;
GO

--*****  NOW DELETE THE MDF FILE  *****

ALTER DATABASE [AdventureWorks2019] SET ONLINE;
GO

-- Ooops... No longer MDF file...

-- Now let's try to backup that last transaction we inserted.
BACKUP LOG [AdventureWorks2019]
TO DISK = 'C:\DataSat20\Demos\backups\Adv2019_taillog.trn'
WITH INIT, NO_TRUNCATE;
GO

-- Now let's restore our base full backup, all our transaction logs including the taillog we just made.
USE MASTER;
GO
RESTORE DATABASE [AdventureWorks2019] FROM DISK = 'C:\DataSat20\Demos\Backups\Adv2019_Base.BAK' WITH NORECOVERY, REPLACE;
RESTORE LOG [AdventureWorks2019] FROM DISK = 'C:\DataSat20\Demos\backups\Adv2019_taillog.trn' WITH NORECOVERY;
RESTORE DATABASE [AdventureWorks2019] WITH RECOVERY;
GO

-- Now let's see if we can count our black products.
USE [AdventureWorks2019];
GO

SELECT COUNT(*) BlackProductsAfterUpdate FROM Production.Product WHERE Color ='Black';
GO
