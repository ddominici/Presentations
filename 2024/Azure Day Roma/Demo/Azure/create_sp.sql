CREATE OR ALTER PROC dbo.SalesByCategory
(
    @CategoryName dbo.Name = NULL
)
AS
    SET NOCOUNT ON

    SELECT pc.Name, SUM(sod.LineTotal) AS Total
    FROM SalesLT.SalesOrderDetail sod
    JOIN SalesLT.Product p on p.ProductID = sod.ProductID
    LEFT JOIN SalesLT.ProductCategory pc on pc.ProductCategoryID = p.ProductCategoryID
    WHERE (pc.Name = @CategoryName OR @CategoryName IS NULL)
    GROUP BY pc.Name
GO

EXEC dbo.SalesByCategory

EXEC dbo.SalesByCategory 'Bike Racks'
