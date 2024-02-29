--
-- Create a custom non-privileged user for use with Telegraf data collector
--
USE master;
GO
CREATE LOGIN [telegraf] WITH PASSWORD = N'P@ssw0rd!';
GO
GRANT VIEW SERVER STATE TO [telegraf];
GO
GRANT VIEW ANY DEFINITION TO [telegraf];
GO
