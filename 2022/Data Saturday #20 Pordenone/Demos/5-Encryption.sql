/*
 * Backup Encryption
 *
 * Richiede il backup del database MIcrosoft AdventureWorks2019
 * scaricabile qui: https://github.com/Microsoft/sql-server-samples/releases/tag/adventureworks
 *
 */

-- Restore AdventureWorks2019 from our base backup.
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

IF EXISTS(SELECT * FROM sys.certificates WHERE name = 'EncryptedBackupCert')
BEGIN
	DROP certificate EncryptedBackupCert
END

/*

Delete C:\Datasat20\Demos\Certs content to remove backups of encryption keys

DROP master key

-- Creates a database master key.
-- The key is encrypted using the password

*/


--CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'MyC0mpl3xP@ssw0rd!';
--GO

-- Next you will have to create a certificate, or asymmetric key, for
-- the instance if one does not already exist.
-- Creates a new certificate for your instance

CREATE CERTIFICATE [EncryptedBackupCert]
	WITH SUBJECT = 'Backup Encryption Certificate';
GO

-- If you back up the database now with encryption, you would get an
-- error warning the encryption key has not been backed up

BACKUP MASTER KEY TO FILE = 'C:\Datasat20\Demos\certs\MasterKey'
    ENCRYPTION BY PASSWORD = 'MyC0mpl3xP@ssw0rd!';
GO

-- You should also backup the server certificate

BACKUP CERTIFICATE [EncryptedBackupCert]
	TO FILE = 'C:\Datasat20\Demos\certs\EncryptedBackupCert'
    WITH PRIVATE KEY ( FILE = 'C:\Datasat20\Demos\certs\EncryptedBackupCertKey' ,
    ENCRYPTION BY PASSWORD = 'MyC0mpl3xP@ssw0rd!' );
GO

--Backup using T-SQL
BACKUP DATABASE [AdventureWorks2019]
	TO DISK = 'C:\Datasat20\Demos\Backups\Adv2019_Compressed_Encrypted.BAK'
	WITH COMPRESSION, ENCRYPTION
		(ALGORITHM = AES_256, SERVER CERTIFICATE = EncryptedBackupCert);
GO

BACKUP DATABASE [AdventureWorks2019]
	TO DISK = 'C:\Datasat20\Demos\Backups\Adv2019_NC.BAK';
GO

/*
To restore an encrypted database, you do not have to specify any encryption
parameters.
You do need to have the certificate or asymmetric key that you used to encrypt
the backup file.
This key or certificate must be available on the instance you are restoring to.
Your user account will need to have VIEW DEFINITION permissions on the key or
certificate.
If you are restoring a backup encrypted from TDE, the TDE certificate will have
to be available on the instance you are restoring to, as well.
*/

RESTORE DATABASE [AdventureWorks2019]
	FROM DISK = 'C:\Datasat20\Demos\Backups\Adv2019_Compressed_Encrypted.BAK'
	WITH REPLACE;
GO

-- Drop certificate
DROP CERTIFICATE [EncryptedBackupCert];
GO

-- Attempt restore to show error
RESTORE DATABASE [AdventureWorks2019]
	FROM DISK = 'C:\Datasat20\Demos\Backups\Adv2019_Compressed_Encrypted.BAK'
	WITH REPLACE;
GO

-- Create the same certificate - NOT RESTORED
USE [master];
GO
CREATE CERTIFICATE [EncryptedBackupCert]
   WITH SUBJECT = 'Backup Encryption Certificate';
GO

-- Attempt restore again
RESTORE DATABASE [AdventureWorks2019]
	FROM DISK = 'C:\Datasat20\Demos\Backups\Adv2019_Compressed_Encrypted.BAK'
	WITH REPLACE;
GO

--Drop certificate
DROP CERTIFICATE [EncryptedBackupCert];
GO

-- Restore certificate
CREATE CERTIFICATE [EncryptedBackupCert]
	FROM FILE = 'C:\Datasat20\Demos\Certs\EncryptedBackupCert'
    WITH PRIVATE KEY ( FILE = 'C:\Datasat20\Demos\Certs\EncryptedBackupCertkey' ,
    DECRYPTION BY PASSWORD = 'MyC0mpl3xP@ssw0rd!');
GO

-- Show restore successful
RESTORE DATABASE [AdventureWorks2019]
	FROM DISK = 'C:\Datasat20\Demos\Backups\Adv2019_Compressed_Encrypted.BAK'
	WITH REPLACE;
GO

SELECT TOP 10 * FROM [AdventureWorks2019].Production.Product

-- EOF
