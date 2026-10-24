--
-- Enable external endpoints
--
USE master;
GO
sp_configure 'external rest endpoint enabled', 1;
GO
RECONFIGURE WITH OVERRIDE;
GO

--
-- Enable preview features (required for vector and AI capabilities)
--
USE [AdventureWorks];
GO

ALTER DATABASE [AdventureWorks] SET COMPATIBILITY_LEVEL = 170;
GO

ALTER DATABASE SCOPED CONFIGURATION  
SET PREVIEW_FEATURES = ON;
GO

-- Switch to the embeddings database
PRINT 'Step 2: Creating external model connection to load-balanced Ollama...';
GO

-- Create external model pointing to our load-balanced nginx endpoint
-- (443 = nginx load balancer, 444 = direct backend)
CREATE EXTERNAL MODEL ollama_lb
AUTHORIZATION dbo
WITH (
    LOCATION = 'https://host.docker.internal:443/api/embed',
    API_FORMAT = 'Ollama',
    MODEL_TYPE = EMBEDDINGS,
    MODEL = 'nomic-embed-text',
    PARAMETERS = '{ "sql_rest_options": { "retry_count": 10 } }'
);
GO

SELECT AI_GENERATE_EMBEDDINGS(N'Hello from SQL' USE MODEL ollama_lb);
GO

CREATE EXTERNAL MODEL ollama_single
WITH (
    LOCATION = 'https://host.docker.internal:444/api/embed',
    API_FORMAT = 'Ollama',
    MODEL_TYPE = EMBEDDINGS,
    MODEL = 'nomic-embed-text',
    PARAMETERS = '{ "sql_rest_options": { "retry_count": 10 } }'
);
GO


PRINT 'Testing load-balanced Ollama connection...';
GO

-- Test the external model connection (load balancer)
BEGIN TRY
    DECLARE @test_result NVARCHAR(MAX);
    DECLARE @test_vector VECTOR(768);
    
    SET @test_vector = AI_GENERATE_EMBEDDINGS(N'test message for load balancer' USE MODEL ollama_lb);
    SET @test_result = CONVERT(NVARCHAR(MAX), @test_vector);
    
    IF @test_result IS NOT NULL AND LEN(@test_result) > 10
    BEGIN
        PRINT 'SUCCESS: Load-balanced Ollama connection working!';
        PRINT 'Vector length: ' + CAST(LEN(@test_result) AS VARCHAR(10)) + ' characters';
        PRINT 'Vector: ' + CAST(@test_result AS VARCHAR(MAX)) + ' characters';
    END
    ELSE
    BEGIN
        PRINT 'WARNING: Connection established but no valid response received.';
    END
END TRY
BEGIN CATCH
    PRINT 'ERROR: Failed to connect to load-balanced Ollama:';
    PRINT ERROR_MESSAGE();
END CATCH
GO


-- Test the external model connection (single backend)
BEGIN TRY
    DECLARE @test_result NVARCHAR(MAX);
    DECLARE @test_vector VECTOR(768);
    
    SET @test_vector = AI_GENERATE_EMBEDDINGS(N'test message for load balancer' USE MODEL ollama_single);
    SET @test_result = CONVERT(NVARCHAR(MAX), @test_vector);
    
    IF @test_result IS NOT NULL AND LEN(@test_result) > 10
    BEGIN
        PRINT 'SUCCESS: Load-balanced Ollama connection working!';
        PRINT 'Vector length: ' + CAST(LEN(@test_result) AS VARCHAR(10)) + ' characters';
        PRINT 'Vector: ' + CAST(@test_result AS VARCHAR(MAX)) + ' characters';
    END
    ELSE
    BEGIN
        PRINT 'WARNING: Connection established but no valid response received.';
    END
END TRY
BEGIN CATCH
    PRINT 'ERROR: Failed to connect to load-balanced Ollama:';
    PRINT ERROR_MESSAGE();
END CATCH
GO

-- Get and set the database compatibility level (required for ENABLE_PARALLEL_PLAN_PREFERENCE hint)
SELECT compatibility_level
FROM sys.databases
WHERE name = 'StackOverflow_Embeddings_Small';


PRINT 'Setting database compatibility level to 170...';
ALTER DATABASE [StackOverflow_Embeddings_Small] SET COMPATIBILITY_LEVEL = 170;




-- Check CPU count and hyperthreading ratio

SELECT cpu_count AS [Logical CPU Count],
       hyperthread_ratio AS [Hyperthread Ratio],
       cpu_count/hyperthread_ratio AS [Physical CPU Count]
FROM sys.dm_os_sys_info WITH (NOLOCK) OPTION (RECOMPILE);

USE master;
GO

EXECUTE sp_configure 'show advanced options', 1;
GO

RECONFIGURE WITH OVERRIDE;
GO

EXECUTE sp_configure 'max degree of parallelism', 4;
GO

RECONFIGURE WITH OVERRIDE;
GO

EXECUTE sp_configure 'show advanced options', 0;
GO

RECONFIGURE;
GO




-- Compare embedding generation performance: load-balanced vs single endpoint
USE [AdventureWorks];
GO

DROP TABLE IF EXISTS Production.ProductDescriptionEmbeddings;
GO
CREATE TABLE Production.ProductDescriptionEmbeddings
( 
  Embedding vector(768), -- Floating point 32 = 4KB per row
  ProductDescEmbeddingID INT IDENTITY NOT NULL PRIMARY KEY CLUSTERED,
  ProductID INT NOT NULL,
  ProductDescriptionID INT NOT NULL,
  ProductModelID INT NOT NULL
 );
GO

-- Enable timing and IO statistics for performance comparison
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- Test 1: Load-balanced endpoint (nginx)
PRINT 'Generating embeddings using LOAD-BALANCED endpoint...';

-- Populate rows with embeddings
-- Need to make sure and only get Products that have ProductModels
-- On this machine: 1:14 seconds - 588 rows - mbxai
INSERT INTO Production.ProductDescriptionEmbeddings
SELECT AI_GENERATE_EMBEDDINGS(pd.Description USE MODEL ollama_lb)
    ,  p.ProductID
    ,  pmpdc.ProductDescriptionID
    ,  pmpdc.ProductModelID
    --,  pmpdc.CultureID, 
FROM Production.ProductModelProductDescriptionCulture pmpdc
JOIN Production.Product p ON pmpdc.ProductModelID = p.ProductModelID
    --AND pmpdc.CultureID IN ('en', 'fr')
JOIN Production.ProductDescription pd ON pd.ProductDescriptionID = pmpdc.ProductDescriptionID
OPTION(USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE'))
GO

/*

SQL Server parse and compile time: 
   CPU time = 0 ms, elapsed time = 0 ms.
SQL Server parse and compile time: 
   CPU time = 16 ms, elapsed time = 16 ms.
Table 'Product'. Scan count 5, logical reads 40, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'ProductModelProductDescriptionCulture'. Scan count 5, logical reads 13, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Worktable'. Scan count 118, logical reads 1294, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'ProductDescription'. Scan count 5, logical reads 55, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'ProductDescriptionEmbeddings'. Scan count 0, logical reads 1472, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
 SQL Server Execution Times:
   CPU time = 1328 ms,  elapsed time = 49496 ms.
(588 righe interessate)
Tempo di esecuzione totale: 00:00:49.517


SQL Server parse and compile time: 
   CPU time = 12 ms, elapsed time = 12 ms.
Table 'ProductModelProductDescriptionCulture'. Scan count 4, logical reads 13, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Product'. Scan count 5, logical reads 40, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Worktable'. Scan count 37, logical reads 948, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'ProductDescription'. Scan count 5, logical reads 55, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'ProductDescriptionEmbeddings'. Scan count 0, logical reads 4415, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
 SQL Server Execution Times:
   CPU time = 3737 ms,  elapsed time = 179079 ms.
(1764 righe interessate)
Tempo di esecuzione totale: 00:02:59.097
*/

-- Test 2: Single endpoint (direct backend), and force a serial plan of DOP 1
PRINT 'Generating embeddings using SINGLE endpoint...';

TRUNCATE TABLE Production.ProductDescriptionEmbeddings;

INSERT INTO Production.ProductDescriptionEmbeddings
SELECT AI_GENERATE_EMBEDDINGS(pd.Description USE MODEL ollama_single)
    ,  p.ProductID
    ,  pmpdc.ProductDescriptionID
    ,  pmpdc.ProductModelID
    --,  pmpdc.CultureID, 
FROM Production.ProductModelProductDescriptionCulture pmpdc
JOIN Production.Product p ON pmpdc.ProductModelID = p.ProductModelID
    --AND pmpdc.CultureID IN ('en', 'fr')
JOIN Production.ProductDescription pd ON pd.ProductDescriptionID = pmpdc.ProductDescriptionID
GO

/*

SQL Server parse and compile time: 
   CPU time = 14 ms, elapsed time = 14 ms.
Table 'ProductDescriptionEmbeddings'. Scan count 0, logical reads 1472, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Workfile'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Product'. Scan count 1, logical reads 15, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'ProductModelProductDescriptionCulture'. Scan count 1, logical reads 6, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'ProductDescription'. Scan count 1, logical reads 20, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
 SQL Server Execution Times:
   CPU time = 1359 ms,  elapsed time = 50171 ms.
(588 righe interessate)
Tempo di esecuzione totale: 00:00:50.189



SQL Server parse and compile time: 
   CPU time = 11 ms, elapsed time = 11 ms.
 SQL Server Execution Times:
   CPU time = 1 ms,  elapsed time = 6 ms.
Table 'ProductDescriptionEmbeddings'. Scan count 0, logical reads 8722, physical reads 0, page server reads 0, read-ahead reads 351, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Workfile'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'ProductDescription'. Scan count 1, logical reads 20, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'ProductModelProductDescriptionCulture'. Scan count 1, logical reads 6, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Product'. Scan count 1, logical reads 15, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
 SQL Server Execution Times:
   CPU time = 3966 ms,  elapsed time = 193267 ms.
(1764 righe interessate)
Tempo di esecuzione totale: 00:03:13.291
*/

