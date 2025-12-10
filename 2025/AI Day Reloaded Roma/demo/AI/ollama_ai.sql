/*
 *  SQL server 2025 e Ollama
 *
 *
 *
 *  Invoke-RestMethod -Method Post -Uri "https://192.168.184.217:11443/api/embeddings" `
 *    -Body '{"model": "nomic-embed-text", "prompt": "This is a test sentence to embed."}' `
 *    -ContentType 'application/json'
 *
 */

--
-- Step 0 - Setup
--

USE master;
GO
sp_configure 'external rest endpoint enabled', 1;
GO
RECONFIGURE WITH OVERRIDE;
GO

-- Enable DiskANN for vector indexes
USE AdventureWorks2025;
GO
ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
GO

--
-- Step 1 - Create table to store embeddings
--

use AdventureWorks2025;
go

DROP TABLE IF EXISTS Production.ProductDescriptionEmbeddings;
GO

CREATE TABLE Production.ProductDescriptionEmbeddings
( 
  ProductDescEmbeddingID INT IDENTITY NOT NULL PRIMARY KEY CLUSTERED,
  ProductID INT NOT NULL,
  ProductDescriptionID INT NOT NULL,
  ProductModelID INT NOT NULL,
  CultureID nchar(6) NOT NULL,
  Embedding vector(768)
);

--
-- Step 2 - Creo l'external model
--

IF EXISTS(SELECT * FROM sys.external_models WHERE name = 'Ollama_NomicEmbedText')
DROP EXTERNAL MODEL Ollama_NomicEmbedText;
GO

CREATE EXTERNAL MODEL Ollama_NomicEmbedText
AUTHORIZATION dbo
WITH (
	LOCATION = 'https://192.168.184.217:11443/api/embed',
	API_FORMAT = 'Ollama',
	MODEL_TYPE = embeddings,
	MODEL = 'nomic-embed-text',
	);

--
-- Step 3 - Popolo le righe con gli embeddings
--
TRUNCATE TABLE Production.ProductDescriptionEmbeddings;

;WITH src AS
(
	SELECT p.ProductID
		, pmpdc.ProductDescriptionID
		, pmpdc.ProductModelID
		, pmpdc.CultureID
		, pd.Description
		--, AI_GENERATE_EMBEDDINGS(pd.Description USE MODEL Ollama_NomicEmbedText)
	FROM Production.ProductModelProductDescriptionCulture pmpdc
	JOIN Production.Product p 
		ON pmpdc.ProductModelID = p.ProductModelID
	JOIN Production.ProductDescription pd 
		ON pd.ProductDescriptionID = pmpdc.ProductDescriptionID
	LEFT OUTER JOIN Production.ProductDescriptionEmbeddings pde 
		ON pde.ProductID = p.ProductID
		AND pde.ProductModelID = pmpdc.ProductModelID
		AND pde.CultureID = pmpdc.CultureID
	WHERE pde.Embedding IS NULL
)
INSERT INTO Production.ProductDescriptionEmbeddings
SELECT
	  src.ProductID
	, src.ProductDescriptionID
	, src.ProductModelID
	, src.CultureID
	, AI_GENERATE_EMBEDDINGS(src.Description USE MODEL Ollama_NomicEmbedText)
FROM src
ORDER BY src.ProductID;
GO

-- Verifico che gli embeddings siano stati calcolati per tutti i prodotti
SELECT * 
FROM Production.ProductDescriptionEmbeddings 
WHERE embedding IS NOT NULL
ORDER BY ProductID, ProductModelID, CultureID;
GO

--
-- Step 4 - Uso le nuove funzioni VECTOR_DISTANCE e VECTOR_SEARCH per cercare
--          prodotti che corrispondono alla domanda in linguaggio naturale
--
USE [AdventureWorks];
GO

CREATE OR ALTER procedure [find_relevant_products]
	@prompt nvarchar(max), -- NL prompt
	@stock smallint = 500, -- Only show product with stock level of >= 500. User can override
	@top int = 10, -- Only show top 10. User can override
	@min_similarity decimal(19,16) = 0.3 -- Similarity level that user can change but recommend to leave default
as
	if (@prompt is null) return;

	declare @retval int, @vector vector(768);

	--exec @retval = get_embedding @prompt, @vector output;
	select @vector = AI_GENERATE_EMBEDDINGS(@prompt USE MODEL Ollama_NomicEmbedText);

	if (@retval != 0) return;

	-- Use vector_distance to find similar products
	-- Use a hybrid search to only show products with a stock_quantity > 25

	with cteSimilarEmbeddings as 
	(
		select top(@top)
			  pde.ProductID
			, pde.ProductModelID
			, pde.ProductDescriptionID
			, pde.CultureID 
			, vector_distance('cosine', pde.[Embedding], @vector) as distance
		from 
			Production.ProductDescriptionEmbeddings pde
		order by
			distance 
	)
	select 
		  p.Name as ProductName
		, pd.Description as ProductDescription
		, p.SafetyStockLevel as StockQuantity
		, p.ListPrice
	from 
		cteSimilarEmbeddings se
	join Production.Product p
			on p.ProductID = se.ProductID
	join Production.ProductDescription pd
		on pd.ProductDescriptionID = se.ProductDescriptionID
	where (1-distance) > @min_similarity
		and p.SafetyStockLevel >= @stock
	order by    
		distance asc;
GO

EXEC find_relevant_products
	@prompt = N'Show me stuff for extreme outdoor sports',
	@stock = 100, 
	@top = 20;
GO 

EXEC find_relevant_products
	@prompt = N'Montrez-moi des trucs pour les sports de plein air extrêmes',
	@stock = 100, 
	@top = 20;
GO 

EXEC find_relevant_products
	@prompt = N'Show me cheap bikes',
	@stock = 1, 
	@top = 10;
GO 

--
--
--

CREATE VECTOR INDEX product_vector_index 
ON Production.ProductDescriptionEmbeddings (Embedding)
WITH (METRIC = 'cosine', TYPE = 'diskann', MAXDOP = 8);
GO

CREATE OR ALTER procedure [find_relevant_products_vector_search]
	@prompt nvarchar(max), -- NL prompt
	@stock smallint = 500, -- Only show product with stock level of >= 500. User can override
	@top int = 10, -- Only show top 10. User can override
	@min_similarity decimal(19,16) = 0.3 -- Similarity level that user can change but recommend to leave default
AS
	IF (@prompt is null) RETURN;

	DECLARE @retval int, @vector vector(768);

	SELECT @vector = AI_GENERATE_EMBEDDINGS(@prompt USE MODEL Ollama_NomicEmbedText);

	IF (@retval != 0) RETURN;

	SELECT 
		  p.Name as ProductName
		, pd.Description as ProductDescription
		, p.SafetyStockLevel as StockLevel
		, p.ListPrice
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

EXEC find_relevant_products_vector_search
	@prompt = N'Show me stuff for extreme outdoor sports',
	@stock = 100, 
	@top = 20;
GO

SET STATISTICS IO, TIME ON
GO

DBCC FREEPROCCACHE;
DBCC DROPCLEANBUFFERS;

EXEC find_relevant_products
	@prompt = N'Show me stuff for extreme outdoor sports',
	@stock = 100, 
	@top = 20;
GO 

EXEC find_relevant_products_vector_search
	@prompt = N'Show me stuff for extreme outdoor sports',
	@stock = 100, 
	@top = 20;
GO

/*

SQL Server parse and compile time: 
   CPU time = 0 ms, elapsed time = 0 ms.

 SQL Server Execution Times:
   CPU time = 0 ms,  elapsed time = 0 ms.
SQL Server parse and compile time: 
   CPU time = 0 ms, elapsed time = 0 ms.
SQL Server parse and compile time: 
   CPU time = 16 ms, elapsed time = 17 ms.

 SQL Server Execution Times:
   CPU time = 0 ms,  elapsed time = 0 ms.

 SQL Server Execution Times:
   CPU time = 0 ms,  elapsed time = 43 ms.

 SQL Server Execution Times:
   CPU time = 0 ms,  elapsed time = 0 ms.

(20 rows affected)
Table 'ProductDescription'. Scan count 0, logical reads 40, physical reads 2, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Product'. Scan count 0, logical reads 40, physical reads 3, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'ProductDescriptionEmbeddings'. Scan count 1, logical reads 886, physical reads 0, page server reads 0, read-ahead reads 881, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

(1 row affected)

 SQL Server Execution Times:
   CPU time = 15 ms,  elapsed time = 80 ms.

 SQL Server Execution Times:
   CPU time = 31 ms,  elapsed time = 141 ms.
SQL Server parse and compile time: 
   CPU time = 0 ms, elapsed time = 0 ms.

 SQL Server Execution Times:
   CPU time = 0 ms,  elapsed time = 0 ms.

-------------------------------------------------------------------------------

SQL Server parse and compile time: 
   CPU time = 0 ms, elapsed time = 0 ms.

 SQL Server Execution Times:
   CPU time = 0 ms,  elapsed time = 0 ms.
SQL Server parse and compile time: 
   CPU time = 0 ms, elapsed time = 0 ms.
SQL Server parse and compile time: 
   CPU time = 47 ms, elapsed time = 47 ms.

 SQL Server Execution Times:
   CPU time = 0 ms,  elapsed time = 0 ms.

 SQL Server Execution Times:
   CPU time = 0 ms,  elapsed time = 46 ms.

 SQL Server Execution Times:
   CPU time = 0 ms,  elapsed time = 0 ms.

(18 rows affected)
Table 'ProductDescriptionEmbeddings'. Scan count 0, logical reads 849, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'ProductDescription'. Scan count 0, logical reads 36, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Product'. Scan count 0, logical reads 40, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'Worktable'. Scan count 21, logical reads 1023, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
Table 'vector_index_Graph_Edge_table_1367675920_1152000'. Scan count 0, logical reads 72, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

(1 row affected)

 SQL Server Execution Times:
   CPU time = 0 ms,  elapsed time = 78 ms.

 SQL Server Execution Times:
   CPU time = 47 ms,  elapsed time = 172 ms.
SQL Server parse and compile time: 
   CPU time = 0 ms, elapsed time = 0 ms.

 SQL Server Execution Times:
   CPU time = 0 ms,  elapsed time = 0 ms.

*/