-- SQL Server Configuration for Ollama Integration
-- Configures SQL Server 2025 RC1 for external REST endpoint communication
-- Based on the ollama-sql-faststart project configuration

PRINT 'Starting SQL Server configuration for Ollama integration...';
GO

-- Enable external REST endpoint invocation
-- This is required for SQL Server to communicate with external API endpoints
PRINT 'Enabling external REST endpoint invocation...';
GO
sp_configure 'external rest endpoint enabled', 1;
GO
RECONFIGURE WITH OVERRIDE;
GO

PRINT 'SQL Server configuration completed successfully!';
GO

-- End of configuration script