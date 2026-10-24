    /*  Demo 2 — Azure SQL Database
        Same insurance schema as demo 1, plus dbo.Claims (used again in demo 3).
        Run against the Azure SQL database named InsuranceDemo.  */

    DROP VIEW IF EXISTS dbo.vw_PolicySummary;
    DROP TABLE IF EXISTS dbo.Claims;
    DROP TABLE IF EXISTS dbo.Policies;
    DROP TABLE IF EXISTS dbo.Brokers;
    GO

    CREATE TABLE dbo.Brokers
    (
        id        INT IDENTITY(1,1) CONSTRAINT PK_Brokers PRIMARY KEY,
        code      VARCHAR(12)   NOT NULL CONSTRAINT UQ_Brokers_code UNIQUE,
        name      NVARCHAR(120) NOT NULL,
        city      NVARCHAR(80)  NOT NULL,
        entra_oid UNIQUEIDENTIFIER NULL      -- object id of the broker's Entra user
    );
    GO

    CREATE TABLE dbo.Policies
    (
        id                INT IDENTITY(1,1) CONSTRAINT PK_Policies PRIMARY KEY,
        policy_number     VARCHAR(20)   NOT NULL CONSTRAINT UQ_Policies_number UNIQUE,
        product           NVARCHAR(60)  NOT NULL,
        status            VARCHAR(12)   NOT NULL,
        premium           DECIMAL(12,2) NOT NULL,
        commission_amount DECIMAL(12,2) NOT NULL,
        broker_id         INT           NOT NULL
            CONSTRAINT FK_Policies_Brokers REFERENCES dbo.Brokers(id),
        broker_oid        UNIQUEIDENTIFIER NULL,   -- denormalised for the DAB policy below
        effective_date    DATE          NOT NULL,
        expiry_date       DATE          NOT NULL
    );
    GO

    CREATE TABLE dbo.Claims
    (
        id            INT IDENTITY(1,1) CONSTRAINT PK_Claims PRIMARY KEY,
        claim_number  VARCHAR(20)   NOT NULL CONSTRAINT UQ_Claims_number UNIQUE,
        policy_number VARCHAR(20)   NOT NULL,
        opened_on     DATE          NOT NULL,
        status        VARCHAR(12)   NOT NULL,
        reserve       DECIMAL(12,2) NOT NULL,
        paid          DECIMAL(12,2) NOT NULL CONSTRAINT DF_Claims_paid DEFAULT (0)
    );
    GO

    CREATE INDEX IX_Policies_broker_oid ON dbo.Policies(broker_oid);
    GO

    INSERT INTO dbo.Brokers (code, name, city, entra_oid) VALUES
    ('BRK-MI-01', N'Assicurazioni Navigli',   N'Milano', NULL),
    ('BRK-RM-02', N'Tevere Broker',           N'Roma',   NULL),
    ('BRK-TO-03', N'Mole Insurance Partners', N'Torino', NULL);
    GO

    INSERT INTO dbo.Policies
    (policy_number, product, status, premium, commission_amount, broker_id, effective_date, expiry_date)
    VALUES
    ('POL-2026-0001', N'Motor - comprehensive',  'active',  1420.00, 142.00, 1, '2026-01-15', '2027-01-14'),
    ('POL-2026-0002', N'Home - fire and theft',  'active',   380.50,  38.05, 1, '2026-02-01', '2027-01-31'),
    ('POL-2026-0003', N'Motor - third party',    'lapsed',   610.00,  61.00, 2, '2025-03-10', '2026-03-09'),
    ('POL-2026-0005', N'Professional indemnity', 'pending', 2850.00, 285.00, 3, '2026-05-20', '2027-05-19');
    GO

    INSERT INTO dbo.Claims (claim_number, policy_number, opened_on, status, reserve, paid) VALUES
    ('CLM-2026-0001', 'POL-2026-0001', '2026-03-02', 'open',     4500.00,    0.00),
    ('CLM-2026-0002', 'POL-2026-0002', '2026-04-18', 'closed',   1200.00, 1150.00),
    ('CLM-2026-0003', 'POL-2026-0005', '2026-06-30', 'assessed',12000.00,    0.00);
    GO
