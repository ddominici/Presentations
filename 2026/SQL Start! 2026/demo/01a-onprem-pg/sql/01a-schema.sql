/*  Demo 1a — PostgreSQL 17
    Small insurance schema: two tables, one view, one function (stand-in for the stored procedure).
    Every table has a primary key: DAB refuses to start on a table without one.
*/

-- \connect InsuranceDemo

CREATE SCHEMA IF NOT EXISTS public;

DROP VIEW IF EXISTS vw_policysummary;
DROP FUNCTION IF EXISTS usp_renewpolicy(VARCHAR, INT);
DROP TABLE IF EXISTS policies;
DROP TABLE IF EXISTS brokers;

CREATE TABLE brokers
(
    id          INT GENERATED ALWAYS AS IDENTITY CONSTRAINT PK_Brokers PRIMARY KEY,
    code        VARCHAR(12)   NOT NULL CONSTRAINT UQ_Brokers_code UNIQUE,
    name        VARCHAR(120)  NOT NULL,
    city        VARCHAR(80)   NOT NULL,
    entra_oid   UUID          NULL,        -- used by the item-level policy in demo 2
    created_at  TIMESTAMPTZ(0) NOT NULL CONSTRAINT DF_Brokers_created DEFAULT now()
);

CREATE TABLE policies
(
    id                INT GENERATED ALWAYS AS IDENTITY CONSTRAINT PK_Policies PRIMARY KEY,
    policy_number     VARCHAR(20)   NOT NULL CONSTRAINT UQ_Policies_number UNIQUE,
    product           VARCHAR(60)   NOT NULL,
    status            VARCHAR(12)   NOT NULL CONSTRAINT CK_Policies_status
                          CHECK (status IN ('active','lapsed','cancelled','pending')),
    premium           DECIMAL(12,2) NOT NULL,
    commission_amount DECIMAL(12,2) NOT NULL,   -- hidden from the reader role in demo 2
    broker_id         INT           NOT NULL
                          CONSTRAINT FK_Policies_Brokers REFERENCES Brokers(id),
    effective_date    DATE          NOT NULL,
    expiry_date       DATE          NOT NULL,
    updated_at        TIMESTAMPTZ(0) NOT NULL CONSTRAINT DF_Policies_updated DEFAULT now()
);

CREATE INDEX IX_Policies_status_premium ON policies(status, premium DESC) INCLUDE (product, broker_id);
CREATE INDEX IX_Policies_broker         ON policies(broker_id);

/*  A view is a first-class entity in DAB, but the engine cannot infer a key,
    so the entity must declare --source.key-fields.  */
CREATE VIEW vw_policysummary
AS
SELECT  p.id            AS policy_id,
        p.policy_number,
        p.product,
        p.status,
        p.premium,
        b.code          AS broker_code,
        b.name          AS broker_name,
        b.city          AS broker_city,
        (p.expiry_date - CURRENT_DATE) AS days_to_expiry
FROM Policies AS p
JOIN Brokers  AS b ON b.id = p.broker_id;

/*  Ported from the stored procedure. In DAB 2.0 this can still be published
    as a named MCP tool with --mcp.custom-tool true, but against Postgres
    it needs to be a FUNCTION returning a table so the result set flows
    back to the caller the same way a T-SQL proc's trailing SELECT does.  */
CREATE OR REPLACE FUNCTION usp_renewpolicy(
    p_policy_number VARCHAR(20),
    p_months        INT DEFAULT 12
)
RETURNS TABLE (
    policy_number  VARCHAR(20),
    product        VARCHAR(60),
    status         VARCHAR(12),
    effective_date DATE,
    expiry_date    DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE Policies AS p
    SET expiry_date = (p.expiry_date + (p_months || ' months')::INTERVAL)::DATE,
        status      = 'active',
        updated_at  = now()
    WHERE p.policy_number = p_policy_number;

    RETURN QUERY
    SELECT p.policy_number, p.product, p.status, p.effective_date, p.expiry_date
    FROM   Policies AS p
    WHERE  p.policy_number = p_policy_number;
END;
$$;

-- Call it like: SELECT * FROM dbo.usp_RenewPolicy('POL-0001', 6);