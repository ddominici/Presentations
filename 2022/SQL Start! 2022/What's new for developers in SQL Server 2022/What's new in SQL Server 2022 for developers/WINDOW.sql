USE AdventureWorks2019
GO

/*
ALTER DATABASE AdventureWorks2019 
SET COMPATIBILITY_LEVEL = 150;
GO
*/

-- Before SQL Server 2022
SELECT ROW_NUMBER() OVER (PARTITION BY PostalCode ORDER BY SalesYTD DESC) AS "Row Number"
	, p.LastName
	, s.SalesYTD
	, a.PostalCode
FROM Sales.SalesPerson AS s
    INNER JOIN Person.Person AS p
        ON s.BusinessEntityID = p.BusinessEntityID
    INNER JOIN Person.Address AS a
        ON a.AddressID = p.BusinessEntityID
WHERE TerritoryID IS NOT NULL
    AND SalesYTD <> 0
ORDER BY PostalCode;
GO

/*
ALTER DATABASE AdventureWorks2019 
SET COMPATIBILITY_LEVEL = 160;
GO
*/

-- SQL Server 2022 - new clause WINDOW
SELECT ROW_NUMBER() OVER w AS "Row Number"
	, p.LastName
	, s.SalesYTD
	, a.PostalCode
FROM Sales.SalesPerson AS s
    INNER JOIN Person.Person AS p
        ON s.BusinessEntityID = p.BusinessEntityID
    INNER JOIN Person.Address AS a
        ON a.AddressID = p.BusinessEntityID
WHERE TerritoryID IS NOT NULL
    AND SalesYTD <> 0
WINDOW w AS (PARTITION BY PostalCode ORDER BY SalesYTD DESC)
ORDER BY PostalCode;


-- Before SQL Server 2022
SELECT SalesOrderID, ProductID, OrderQty
    ,SUM(OrderQty)   OVER (PARTITION BY SalesOrderID) AS Total
    ,AVG(OrderQty)   OVER (PARTITION BY SalesOrderID) AS "Avg"
    ,COUNT(OrderQty) OVER (PARTITION BY SalesOrderID) AS "Count"
    ,MIN(OrderQty)   OVER (PARTITION BY SalesOrderID) AS "Min"
    ,MAX(OrderQty)   OVER (PARTITION BY SalesOrderID) AS "Max"
FROM Sales.SalesOrderDetail
WHERE SalesOrderID IN(43659,43664);

-- With SQL Server 2022
SELECT SalesOrderID, ProductID, OrderQty
    ,SUM(OrderQty)   OVER w AS Total
    ,AVG(OrderQty)   OVER w AS "Avg"
    ,COUNT(OrderQty) OVER w AS "Count"
    ,MIN(OrderQty)   OVER w AS "Min"
    ,MAX(OrderQty)   OVER w AS "Max"
FROM Sales.SalesOrderDetail
WHERE SalesOrderID IN(43659,43664)
WINDOW w AS (PARTITION BY SalesOrderID);


--
-- Running totals - Pre SQL Server 2022
--
SELECT H.SalesOrderID, CustomerID, OrderDate, D.OrderQty, 
	SUM(OrderQty) OVER (PARTITION BY CustomerID
						ORDER BY OrderDate, H.SalesOrderID
						ROWS UNBOUNDED PRECEDING) AS runqty
FROM Sales.SalesOrderHeader H
INNER JOIN Sales.SalesOrderDetail D ON D.SalesOrderID = H.SalesOrderID
WHERE OrderQty > 1
ORDER BY CustomerID, OrderDate, H.SalesOrderID

--
-- Runnig totals - SQL Server 2022
--
SELECT H.SalesOrderID, CustomerID, OrderDate, D.OrderQty, SUM(OrderQty) OVER W AS runqty
FROM Sales.SalesOrderHeader H
INNER JOIN Sales.SalesOrderDetail D ON D.SalesOrderID = H.SalesOrderID
WHERE OrderQty > 1
WINDOW w AS (PARTITION BY CustomerID
			ORDER BY OrderDate, H.SalesOrderID
			ROWS UNBOUNDED PRECEDING)
ORDER BY CustomerID, OrderDate, H.SalesOrderID

--
-- Recursive capability
--
SELECT H.SalesOrderID, CustomerID, OrderDate, D.OrderQty, 
	ROW_NUMBER()   OVER orders_win AS rn,
	MAX(OrderDate) OVER customer_win AS GreatestOrderDate,
	SUM(OrderQty)  OVER running_total_win AS RunningTotal
FROM Sales.SalesOrderHeader H
INNER JOIN Sales.SalesOrderDetail D ON D.SalesOrderID = H.SalesOrderID
WHERE OrderQty > 1
WINDOW 
	customer_win      AS (PARTITION BY CustomerID),
	orders_win        AS (customer_win ORDER BY OrderDate, H.SalesOrderID),
	running_total_win AS (orders_win ROWS UNBOUNDED PRECEDING)
ORDER BY CustomerID, OrderDate, H.SalesOrderID

--
-- Mixed capabilities: using a window name and additional windowing elements
--
SELECT H.SalesOrderID, CustomerID, OrderDate, D.OrderQty,
	ROW_NUMBER()   OVER (customer_win ORDER BY OrderDate, H.SalesOrderID) AS rn,
	MAX(OrderDate) OVER customer_win AS GreatestOrderDate
FROM Sales.SalesOrderHeader H
INNER JOIN Sales.SalesOrderDetail D ON D.SalesOrderID = H.SalesOrderID
WHERE OrderQty > 1
WINDOW 
	customer_win      AS (PARTITION BY CustomerID),
	orders_win        AS (customer_win ORDER BY OrderDate, H.SalesOrderID)
ORDER BY CustomerID, OrderDate, H.SalesOrderID