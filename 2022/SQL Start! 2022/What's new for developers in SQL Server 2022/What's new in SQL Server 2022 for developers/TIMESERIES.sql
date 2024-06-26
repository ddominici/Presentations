/*
 * 
 *
 *
 *
 *
 *
 *
 *
 */

USE AdventureWorks2019
GO

SET LANGUAGE ITALIAN
GO

SELECT OrderDate
	, DATENAME(WEEKDAY, OrderDate) AS WeekDay1
	, DATE_BUCKET(WEEK, 1, OrderDate)
	, DATEPART(WEEK, DATE_BUCKET(WEEK, 1, OrderDate)) AS WeekNo
FROM Sales.SalesOrderHeader

--
-- 
--
USE TEMPDB
GO

DROP TABLE IOTDATA
GO

CREATE TABLE IOTDATA
(
	ID BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	DT DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
	T FLOAT NOT NULL DEFAULT (0.0),
	P FLOAT NOT NULL DEFAULT (0.0),
	H FLOAT NOT NULL DEFAULT (0.0)
)
GO

DECLARE @i INT = 0, 
		@t float = 24.0,
		@p float = 9800.0,
		@h float = 50.0;

SET NOCOUNT ON;

WHILE (@i < 500000)
BEGIN
	--PRINT  (CHECKSUM(NEWID())) % 10 + 1
	SET @t = @t + (CHECKSUM(NEWID())) % 10 
	SET @p = @p + (CHECKSUM(NEWID())) % 10 
	SET @h = @h + (CHECKSUM(NEWID())) % 10

	INSERT INTO IOTDATA (T,P,H) VALUES (@t, @p, @h)
	SET @i = @i + 1

END
GO

DECLARE @interval INT = 1;
WITH cte AS
(
	SELECT DT, DATE_BUCKET(SECOND, @interval, DT) DT_MIN, T, P, H
	FROM IOTDATA
)
SELECT DT_MIN, MIN(T) AS MinTemperature, MAX(T) AS MaxTemperature, 
	MIN(P) AS MinPressure, MAX(P) AS MaxPressure, 
	MIN(H) AS MinHumidity, MAX(H) AS MaxHumidity
FROM cte
GROUP BY DT_MIN
ORDER BY DT_MIN

--
-- GENERATE_SERIES
--

SELECT value FROM GENERATE_SERIES(START = 1, STOP = 5);

SELECT value FROM GENERATE_SERIES(START = 1, STOP = 32, STEP = 7);

-- Old way
WITH
    L0 AS ( SELECT 1 AS c 
			FROM (VALUES(1),(1),(1),(1),(1),(1),(1),(1),
                        (1),(1),(1),(1),(1),(1),(1),(1)) AS D(c) ),
    L1 AS ( SELECT 1 AS c FROM L0 AS A CROSS JOIN L0 AS B ),
    L2 AS ( SELECT 1 AS c FROM L1 AS A CROSS JOIN L1 AS B ),
    L3 AS ( SELECT 1 AS c FROM L2 AS A CROSS JOIN L2 AS B ),
    Nums AS ( SELECT ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS rownum FROM L3 )
SELECT rownum AS rn
FROM Nums
WHERE rownum BETWEEN 1 AND 1000;

-- New way
SELECT value FROM GENERATE_SERIES(START = 1, STOP = 1000, STEP = 1);


--
--
--

DROP TABLE IF EXISTS T1;
GO

CREATE TABLE T1
(
	ID INT IDENTITY(1,1) NOT NULL,
	CustomerID INT NOT NULL,
	OrderDate DATETIME NULL,
	Qty INT NOT NULL
)
GO

INSERT INTO T1 (CustomerID, OrderDate, Qty) 
VALUES 
	(1, '20220601', 100), 
	(1, NULL, 200), 
	(1, '20220605', 150),
	(2, '20220608', 120),
	(2, '20220610', 180)
GO

SELECT CustomerID, Qty, OrderDate,
	FIRST_VALUE(OrderDate) /* RESPECT NULLS */ OVER (PARTITION BY CustomerID ORDER BY Qty DESC),
	LAST_VALUE(OrderDate) IGNORE NULLS OVER (PARTITION BY CustomerID ORDER BY Qty DESC)
FROM T1

SELECT CustomerID, Qty, OrderDate,
	FIRST_VALUE(OrderDate) IGNORE NULLS OVER (PARTITION BY CustomerID ORDER BY Qty DESC),
	LAST_VALUE(OrderDate) IGNORE NULLS OVER (PARTITION BY CustomerID ORDER BY Qty DESC)
FROM T1