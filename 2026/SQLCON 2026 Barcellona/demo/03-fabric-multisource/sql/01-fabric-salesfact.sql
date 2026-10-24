/*  Demo 3 — SQL database in Microsoft Fabric.
    Run this in the Fabric SQL query editor, in a database named SalesDemo.

    Fabric SQL is database-type "mssql" for DAB, but it accepts Microsoft Entra
    authentication only. There are no SQL logins, so any flow that needs SQL auth
    (including the VS Code local-container flow) does not apply here.  */

DROP VIEW  IF EXISTS dbo.vw_SalesByRegion;
DROP TABLE IF EXISTS dbo.SalesFact;
GO

CREATE TABLE dbo.SalesFact
(
    id              INT IDENTITY(1,1) CONSTRAINT PK_SalesFact PRIMARY KEY,
    period          CHAR(7)       NOT NULL,          -- 'YYYY-MM'
    region          NVARCHAR(40)  NOT NULL,
    product         NVARCHAR(60)  NOT NULL,
    policies_sold   INT           NOT NULL,
    written_premium DECIMAL(14,2) NOT NULL
);
GO

INSERT INTO dbo.SalesFact (period, region, product, policies_sold, written_premium) VALUES
 ('2026-01', N'Nord Ovest', N'Motor - comprehensive',  412,  585040.00),
 ('2026-01', N'Nord Est',   N'Motor - comprehensive',  268,  380560.00),
 ('2026-01', N'Centro',     N'Home - fire and theft',  531,  202030.50),
 ('2026-02', N'Nord Ovest', N'Motor - comprehensive',  455,  646100.00),
 ('2026-02', N'Sud',        N'Travel - annual',        877,  188555.00),
 ('2026-02', N'Centro',     N'Professional indemnity',  63,  179550.00),
 ('2026-03', N'Nord Ovest', N'Cyber - SME',            104,  122720.00),
 ('2026-03', N'Nord Est',   N'Home - all risks',       298,  280343.50);
GO

CREATE VIEW dbo.vw_SalesByRegion
AS
SELECT  region,
        period,
        SUM(policies_sold)   AS policies_sold,
        SUM(written_premium) AS written_premium
FROM    dbo.SalesFact
GROUP BY region, period;
GO

SELECT COUNT(*) AS rows_loaded FROM dbo.SalesFact;
GO
