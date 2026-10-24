/*  Demo 1 — local SQL Server 2022
    Small insurance schema: two tables, one view, one stored procedure.
    Every table has a primary key: DAB refuses to start on a table without one.  */

IF DB_ID('InsuranceDemo') IS NULL
    EXEC ('CREATE DATABASE InsuranceDemo');
GO
USE InsuranceDemo;
GO

DROP VIEW IF EXISTS dbo.vw_PolicySummary;
DROP PROCEDURE IF EXISTS dbo.usp_RenewPolicy;
DROP TABLE IF EXISTS dbo.Policies;
DROP TABLE IF EXISTS dbo.Brokers;
GO

CREATE TABLE dbo.Brokers
(
    id          INT IDENTITY(1,1) CONSTRAINT PK_Brokers PRIMARY KEY,
    code        VARCHAR(12)   NOT NULL CONSTRAINT UQ_Brokers_code UNIQUE,
    name        NVARCHAR(120) NOT NULL,
    city        NVARCHAR(80)  NOT NULL,
    entra_oid   UNIQUEIDENTIFIER NULL,     -- used by the item-level policy in demo 2
    created_at  DATETIME2(0)  NOT NULL CONSTRAINT DF_Brokers_created DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE dbo.Policies
(
    id                INT IDENTITY(1,1) CONSTRAINT PK_Policies PRIMARY KEY,
    policy_number     VARCHAR(20)   NOT NULL CONSTRAINT UQ_Policies_number UNIQUE,
    product           NVARCHAR(60)  NOT NULL,
    status            VARCHAR(12)   NOT NULL CONSTRAINT CK_Policies_status
                                    CHECK (status IN ('active','lapsed','cancelled','pending')),
    premium           DECIMAL(12,2) NOT NULL,
    commission_amount DECIMAL(12,2) NOT NULL,   -- hidden from the reader role in demo 2
    broker_id         INT           NOT NULL
        CONSTRAINT FK_Policies_Brokers REFERENCES dbo.Brokers(id),
    effective_date    DATE          NOT NULL,
    expiry_date       DATE          NOT NULL,
    updated_at        DATETIME2(0)  NOT NULL CONSTRAINT DF_Policies_updated DEFAULT SYSUTCDATETIME()
);
GO

CREATE INDEX IX_Policies_status_premium ON dbo.Policies(status, premium DESC) INCLUDE (product, broker_id);
CREATE INDEX IX_Policies_broker         ON dbo.Policies(broker_id);
GO

/*  A view is a first-class entity in DAB, but the engine cannot infer a key,
    so the entity must declare --source.key-fields.  */
CREATE VIEW dbo.vw_PolicySummary
AS
SELECT  p.id            AS policy_id,
        p.policy_number,
        p.product,
        p.status,
        p.premium,
        b.code          AS broker_code,
        b.name          AS broker_name,
        b.city          AS broker_city,
        DATEDIFF(DAY, SYSUTCDATETIME(), p.expiry_date) AS days_to_expiry
FROM dbo.Policies AS p
JOIN dbo.Brokers  AS b ON b.id = p.broker_id;
GO

/*  A stored procedure is also an entity — and in DAB 2.0 it can be published
    as a named MCP tool with --mcp.custom-tool true.  */
CREATE PROCEDURE dbo.usp_RenewPolicy
    @policy_number VARCHAR(20),
    @months        INT = 12
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.Policies
       SET expiry_date = DATEADD(MONTH, @months, expiry_date),
           status      = 'active',
           updated_at  = SYSUTCDATETIME()
     WHERE policy_number = @policy_number;

    SELECT policy_number, product, status, effective_date, expiry_date
    FROM   dbo.Policies
    WHERE  policy_number = @policy_number;
END;
GO
