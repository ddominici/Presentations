/*
 * Vector Search
 *
 * Credits to Bob Ward - aka.ms/sqlserver2025demos
 *
 */


-- Prerequisites

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
-- Restore database AdventureWorks2022
--
IF DB_ID('AdventureWorks') IS NOT NULL
BEGIN
    ALTER DATABASE [ADventureWorks] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [AdventureWorks];
END

--RESTORE FILELISTONLY FROM DISK = 'C:\Demo\Backups\AdventureWorks2022.bak'

RESTORE DATABASE AdventureWorks FROM DISK = 'C:\Demo\Backups\AdventureWorks2022.bak'
WITH MOVE 'AdventureWorks2022' TO 'C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\DATA\AdventureWorks.mdf',
MOVE 'AdventureWorks2022_Log' TO 'C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\DATA\AdventureWorks_log.ldf'
GO

-------------------------------------------------------------------------------
-- DEMO 1 - Using full-text search
-------------------------------------------------------------------------------

USE [AdventureWorks];
GO

-- Ensure Full-Text Search is installed
IF 1 = ISNULL(CONVERT(int, FULLTEXTSERVICEPROPERTY('IsFullTextInstalled')), 0)
BEGIN
    PRINT 'Full-Text Search feature is installed.';
END
ELSE
BEGIN
    RAISERROR('Full-Text Search feature is not installed on this instance.', 16, 1);
    RETURN;
END
GO

-- Create a full-text catalog if not present
IF NOT EXISTS (SELECT 1 FROM sys.fulltext_catalogs WHERE name = N'FTC_AdventureWorks')
BEGIN
    PRINT 'Creating full-text catalog [FTC_AdventureWorks]...';
    CREATE FULLTEXT CATALOG [FTC_AdventureWorks];
END
ELSE
BEGIN
    PRINT 'Full-text catalog [FTC_AdventureWorks] already exists.';
END
GO

-- Create the full-text index on [Description] (if not already there)
IF NOT EXISTS (
    SELECT 1
    FROM sys.fulltext_indexes 
    WHERE object_id = OBJECT_ID(N'Production.ProductDescription')
)
BEGIN
    PRINT 'Creating full-text index on Production.ProductDescription(Description)...';
    CREATE FULLTEXT INDEX ON [Production].[ProductDescription]
    (
        [Description] LANGUAGE 1033  -- English
    )
    KEY INDEX [PK_ProductDescription_ProductDescriptionID]  -- existing PK
    ON ([FTC_AdventureWorks])
    WITH (CHANGE_TRACKING = AUTO, STOPLIST = SYSTEM);
END
ELSE
BEGIN
    PRINT 'Full-text index on Production.ProductDescription already exists.';
END
GO

-- Verify the FT index definition
SELECT 
    t.name AS TableName,
    i.name AS KeyIndex,
    fc.name AS CatalogName,
    fi.is_enabled,
    fic.column_id,
    c.name AS ColumnName,
    fic.language_id
FROM sys.fulltext_indexes AS fi
JOIN sys.objects AS t ON fi.object_id = t.object_id
JOIN sys.indexes AS i ON fi.unique_index_id = i.index_id AND i.object_id = t.object_id
JOIN sys.fulltext_catalogs AS fc ON fi.fulltext_catalog_id = fc.fulltext_catalog_id
JOIN sys.fulltext_index_columns AS fic ON fi.object_id = fic.object_id
JOIN sys.columns AS c ON fic.object_id = c.object_id AND fic.column_id = c.column_id
WHERE t.object_id = OBJECT_ID(N'Production.ProductDescription');
GO

-- Perform some search over product description
SELECT * FROM Production.ProductDescription
WHERE Description LIKE '%pillow-y%'
GO
SELECT * FROM Production.ProductDescription
WHERE CONTAINS(Description, '"zero buzz"');
GO
SELECT * FROM Production.ProductDescription
WHERE FREETEXT(Description, 'I want a gliding, pillow‑y feel on battered streets, zero buzz through the hands');
GO

-------------------------------------------------------------------------------
-- Demo 2 - Using AI
-------------------------------------------------------------------------------

--
-- Enable preview features (for DiskANN indexes)
--
USE AdventureWorks;
GO
ALTER DATABASE SCOPED CONFIGURATION  
SET PREVIEW_FEATURES = ON;
GO

IF EXISTS (SELECT * FROM sys.external_models WHERE name = 'Ollama_EmbeddingModel')
DROP EXTERNAL MODEL Ollama_EmbeddingModel;
GO

-- Create the EXTERNAL MODEL
CREATE EXTERNAL MODEL Ollama_EmbeddingModel
WITH ( 
      LOCATION = 'https://192.168.184.217:11443/api/embed',
      API_FORMAT = 'Ollama',
      MODEL_TYPE = EMBEDDINGS,
      MODEL = 'mxbai-embed-large',
      PARAMETERS = '{ "sql_rest_options": { "retry_count": 10 } }'
      );
GO

/*
IF EXISTS(SELECT * FROM sys.external_models WHERE name = 'Ollama_EmbeddingModel')
DROP EXTERNAL MODEL Ollama_EmbeddingModel;
GO

CREATE EXTERNAL MODEL Ollama_EmbeddingModel
AUTHORIZATION dbo
WITH (
	LOCATION = 'https://192.168.184.217:11443/api/embed',
	API_FORMAT = 'Ollama',
	MODEL_TYPE = embeddings,
	MODEL = 'nomic-embed-text',
    PARAMETERS = '{ "sql_rest_options": { "retry_count": 10 } }'
	);
*/

SELECT * FROM sys.external_models;
GO

SELECT AI_GENERATE_EMBEDDINGS(N'Hello from SQL' USE MODEL Ollama_EmbeddingModel);
GO


-- Create a new table to store embeddings
--
DROP TABLE IF EXISTS Production.ProductDescriptionEmbeddings;
GO
CREATE TABLE Production.ProductDescriptionEmbeddings
( 
  Embedding vector(1024), -- Floating point 32 = 4KB per row
  ProductDescEmbeddingID INT IDENTITY NOT NULL PRIMARY KEY CLUSTERED,
  ProductID INT NOT NULL,
  ProductDescriptionID INT NOT NULL,
  ProductModelID INT NOT NULL
 );
GO

-- Populate rows with embeddings
-- Need to make sure and only get Products that have ProductModels
-- On this machine: 1:14 seconds - 588 rows - mbxai
INSERT INTO Production.ProductDescriptionEmbeddings
SELECT AI_GENERATE_EMBEDDINGS(pd.Description USE MODEL Ollama_EmbeddingModel)
    ,  p.ProductID
    ,  pmpdc.ProductDescriptionID
    ,  pmpdc.ProductModelID
    --,  pmpdc.CultureID, 
FROM Production.ProductModelProductDescriptionCulture pmpdc
JOIN Production.Product p ON pmpdc.ProductModelID = p.ProductModelID
    AND pmpdc.CultureID IN ('en', 'fr')
JOIN Production.ProductDescription pd ON pd.ProductDescriptionID = pmpdc.ProductDescriptionID
GO

-- Explore embeddings
SELECT p.ProductID, p.Name, pd.Description, pde.Embedding 
FROM Production.ProductDescriptionEmbeddings pde
JOIN Production.Product p
ON pde.ProductID = p.ProductID
JOIN Production.ProductDescription pd
ON pd.ProductDescriptionID = pde.ProductDescriptionID
GO


USE [AdventureWorks];
GO
CREATE VECTOR INDEX product_vector_index 
ON Production.ProductDescriptionEmbeddings (Embedding)
WITH (METRIC = 'cosine', TYPE = 'diskann', MAXDOP = 8);
GO
-- Vector index typically is only small fraction of overall table size
EXEC sp_spaceused 'Production.ProductDescriptionEmbeddings';
GO

USE [AdventureWorks];
GO

CREATE OR ALTER procedure [find_relevant_products_vector_search]
@prompt nvarchar(max), -- NL prompt
@stock smallint = 500, -- Only show product with stock level of >= 500. User can override
@top int = 10, -- Only show top 10. User can override
@min_similarity decimal(19,16) = 0.3 -- Similarity level that user can change but recommend to leave default
AS
    IF (@prompt is null) RETURN;

    DECLARE @retval int, @vector vector(1024);

    SELECT @vector = AI_GENERATE_EMBEDDINGS(@prompt USE MODEL Ollama_EmbeddingModel);

    IF (@retval != 0) RETURN;

    SELECT p.Name as ProductName, pd.Description as ProductDescription, p.SafetyStockLevel as StockLevel
    FROM vector_search(
	    table = Production.ProductDescriptionEmbeddings as t,
	    column = Embedding,
	    similar_to = @vector,
	    metric = 'cosine',
	    top_n = @top
	    ) as s
    JOIN Production.ProductDescriptionEmbeddings pe
    ON t.ProductDescEmbeddingID = pe.ProductDescEmbeddingID
    JOIN Production.Product p
    ON pe.ProductID = p.ProductID
    JOIN Production.ProductDescription pd
    ON pd.ProductDescriptionID = pe.ProductDescriptionID
    WHERE (1-s.distance) > @min_similarity
    AND p.SafetyStockLevel >= @stock
    ORDER by s.distance;
GO

USE [AdventureWorks];
GO

-- Give it a spin
EXEC find_relevant_products_vector_search
@prompt = N'I want a gliding, pillow‑y feel on battered streets, zero buzz through the hands.',
@stock = 100,
@top = 10
GO

-- Give it a spin
EXEC find_relevant_products_vector_search
@prompt = N'Je veux une impression de douceur et de confort, même quand la route est pourrie, sans que ça vibre dans les mains',
@stock = 100,
@top = 10
GO




USE [AdventureWorks];
GO
CREATE OR ALTER PROCEDURE dbo.measure_vector_search_recall
    @prompt           nvarchar(max),               -- NL query
    @stock            smallint        = 500,       -- min SafetyStockLevel
    @top              int             = 10,        -- K for both methods
    @min_similarity   decimal(19,16)  = 0.3        -- threshold on similarity = 1 - distance
AS
BEGIN
    SET NOCOUNT ON;
    IF (@prompt IS NULL) RETURN;

    DECLARE @qemb vector(1024);

    -- Create query embedding with your model (same pattern you used)
    SELECT @qemb = AI_GENERATE_EMBEDDINGS(@prompt USE MODEL Ollama_EmbeddingModel);

    ;WITH
    ----------------------------------------------------------------------
    -- Exact KNN baseline using VECTOR_DISTANCE (top K by lowest distance)
    ----------------------------------------------------------------------
    exact_knn AS
    (
        SELECT TOP (@top)
            pe.ProductDescEmbeddingID,
            pe.ProductID,
            VECTOR_DISTANCE('cosine', pe.Embedding, @qemb) AS distance
        FROM Production.ProductDescriptionEmbeddings AS pe
        JOIN Production.Product AS p
          ON p.ProductID = pe.ProductID
        WHERE p.SafetyStockLevel >= @stock
        ORDER BY VECTOR_DISTANCE('cosine', pe.Embedding, @qemb) ASC
    ),
    exact_top AS
    (
        -- Apply similarity threshold on the exact distances
        SELECT ProductDescEmbeddingID, ProductID, distance
        FROM exact_knn
        WHERE (1.0 - distance) > @min_similarity
    ),

    ----------------------------------------------------------------------
    -- ANN search using VECTOR_SEARCH (uses DiskANN index if present)
    ----------------------------------------------------------------------
    ann_raw AS
    (
        SELECT
            e.ProductDescEmbeddingID,
            e.ProductID,
            vs.distance
        FROM VECTOR_SEARCH(
                TABLE      = Production.ProductDescriptionEmbeddings AS e,
                COLUMN     = Embedding,
                SIMILAR_TO = @qemb,
                METRIC     = 'cosine',
                TOP_N      = @top
             ) AS vs
        JOIN Production.Product AS p
          ON p.ProductID = e.ProductID
        WHERE p.SafetyStockLevel >= @stock
    ),
    ann_top AS
    (
        -- Apply the same similarity threshold
        SELECT ProductDescEmbeddingID, ProductID, distance
        FROM ann_raw
        WHERE (1.0 - distance) > @min_similarity
    ),

    ----------------------------------------------------------------------
    -- Overlap and counts for recall
    ----------------------------------------------------------------------
    overlap AS
    (
        SELECT a.ProductDescEmbeddingID
        FROM ann_top a
        INNER JOIN exact_top e
            ON e.ProductDescEmbeddingID = a.ProductDescEmbeddingID
    ),
    counts AS
    (
        SELECT
            (SELECT COUNT(*) FROM exact_top)    AS exact_k,
            (SELECT COUNT(*) FROM ann_top)      AS ann_k,
            (SELECT COUNT(*) FROM overlap)      AS overlap_k
    )
    SELECT
        -- recall = overlap / exact_k ; protect against divide-by-zero
        CAST(CASE WHEN exact_k = 0 THEN 0.0
                  ELSE overlap_k * 1.0 / exact_k END AS decimal(6,4)) AS recall
        -- Optional diagnostics (uncomment if you want them)
        --, exact_k AS exact_count
        --, ann_k   AS ann_count
        --, overlap_k AS overlap_count
    FROM counts;
END
GO

-- Give it a spin
EXEC measure_vector_search_recall
@prompt = N'I want a gliding, pillow‑y feel on battered streets, zero buzz through the hands.',
@stock = 100, 
@top = 10;
GO

EXEC measure_vector_search_recall
@prompt = N'Je veux une impression de douceur et de confort, même quand la route est pourrie, sans que ça vibre dans les mains',
@stock = 100, 
@top = 10;
GO





USE [AdventureWorks];
GO
CREATE OR ALTER PROCEDURE [dbo].[find_relevant_products_vector_precise]
    @prompt          nvarchar(max),     -- NL prompt
    @stock           smallint      = 500,  -- Only show products with stock >= @stock
    @top             int           = 10,   -- Top K results to return
    @min_similarity  decimal(19,16) = 0.3  -- Cosine similarity threshold (1 - cosine distance)
AS
BEGIN
    SET NOCOUNT ON;

    IF @prompt IS NULL OR LTRIM(RTRIM(@prompt)) = N'' RETURN;

    DECLARE @vector vector(1024);

    -- Compute the query embedding (keep your model name as-is)
    -- If you prefer to handle errors, wrap in TRY/CATCH and bail if @vector is NULL.
    SELECT @vector = AI_GENERATE_EMBEDDINGS(@prompt USE MODEL Ollama_EmbeddingModel);

    IF @vector IS NULL RETURN;

    ;WITH exact_nn AS
    (
        SELECT TOP (@top)
            p.Name                              AS ProductName,
            pd.Description                      AS ProductDescription,
            p.SafetyStockLevel                  AS StockLevel,
            d.distance                          AS distance,                 -- cosine distance [0..2]
            CAST(1.0 - d.distance AS decimal(19,16)) AS similarity           -- cosine similarity [-1..1]
        FROM Production.ProductDescriptionEmbeddings AS pe
        CROSS APPLY (SELECT VECTOR_DISTANCE('cosine', pe.Embedding, @vector) AS distance) AS d
        JOIN Production.Product            AS p  ON p.ProductID = pe.ProductID
        JOIN Production.ProductDescription AS pd ON pd.ProductDescriptionID = pe.ProductDescriptionID
        WHERE p.SafetyStockLevel >= @stock
        ORDER BY d.distance ASC  -- exact k-NN by true distance
    )
    SELECT
        ProductName,
        ProductDescription,
        StockLevel
    FROM exact_nn
    WHERE similarity >= @min_similarity
    ORDER BY distance ASC;
END
GO

-- Give it a spin
EXEC find_relevant_products_vector_precise
@prompt = N'I want a gliding, pillow‑y feel on battered streets, zero buzz through the hands.',
@stock = 100,
@top = 20,
@min_similarity = 0.1
GO