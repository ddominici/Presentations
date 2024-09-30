--
-- GREATEST
--
SELECT GREATEST('6.62', 3.1415, N'7') AS GreatestVal; 
GO

SELECT GREATEST('Glacier', N'Joshua Tree', 'Mount Rainier') AS GreatestString;  
GO

--
--
--
SELECT P.Name
	, P.SellStartDate
	, P.DiscontinuedDate
	, PM.ModifiedDate AS ModelModifiedDate
    , GREATEST(P.SellStartDate, P.DiscontinuedDate, PM.ModifiedDate) AS LatestDate
FROM Production.Product AS P
INNER JOIN Production.ProductModel AS PM on P.ProductModelID = PM.ProductModelID
WHERE GREATEST(P.SellStartDate, P.DiscontinuedDate, PM.ModifiedDate) >= '2007-01-01'
AND P.SellStartDate >='2007-01-01'
AND P.Name LIKE 'Touring %'
ORDER BY P.Name;

--
--
--
USE TEMPDB
GO

CREATE TABLE dbo.studies (    
    VarX varchar(10) NOT NULL,    
    Correlation decimal(4, 3) NULL 
); 

INSERT INTO dbo.studies VALUES ('Var1', 0.2), ('Var2', 0.825), ('Var3', 0.61); 
GO 

DECLARE @VarX decimal(4, 3) = 0.59;  

SELECT VarX, Correlation, GREATEST(Correlation, 0, @VarX) AS GreatestVar  
FROM dbo.studies;
GO 

--
-- LEAST
--
SELECT LEAST('6.62', 3.1415, N'7') AS GreatestVal; 
GO

SELECT LEAST('Glacier', N'Joshua Tree', 'Mount Rainier') AS GreatestString;  
GO

SELECT P.Name, P.SellStartDate, P.DiscontinuedDate, PM.ModifiedDate AS ModelModifiedDate
    , LEAST(P.SellStartDate, P.DiscontinuedDate, PM.ModifiedDate) AS EarliestDate
FROM AdventureWorks2019.Production.Product AS P
INNER JOIN AdventureWorks2019.Production.ProductModel AS PM on P.ProductModelID = PM.ProductModelID
WHERE LEAST(P.SellStartDate, P.DiscontinuedDate, PM.ModifiedDate) >='2007-01-01'
AND P.SellStartDate >='2007-01-01'
AND P.Name LIKE 'Touring %'
ORDER BY P.Name;

--
-- STRING_SPLIT enable_ordinal
--

SELECT *
FROM STRING_SPLIT('Austin,Texas,Seattle,Washington,Denver,Colorado', ',')

SELECT *
FROM STRING_SPLIT('Austin,Texas,Seattle,Washington,Denver,Colorado', ',', 1)
WHERE ordinal % 2 = 1;

SELECT * 
FROM STRING_SPLIT('E-D-C-B-A', '-', 1) 
ORDER BY ordinal DESC;  
