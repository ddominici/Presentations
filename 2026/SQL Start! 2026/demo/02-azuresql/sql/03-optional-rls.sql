/*  Demo 2, optional extra — database-side row-level security.
    DAB does not replace RLS: it cooperates with it. With
    data-source.options.set-session-context = true, the token claims are pushed into
    SESSION_CONTEXT, so a predicate function can read them.

    Show this only if the room asks "but what about RLS?" — it costs two minutes.  */

DROP SECURITY POLICY IF EXISTS dbo.PolicyBrokerFilter;
DROP FUNCTION IF EXISTS dbo.fn_broker_predicate;
GO

CREATE FUNCTION dbo.fn_broker_predicate(@broker_oid UNIQUEIDENTIFIER)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS ok
    WHERE  @broker_oid = CAST(SESSION_CONTEXT(N'oid') AS UNIQUEIDENTIFIER)
       OR  CAST(SESSION_CONTEXT(N'roles') AS NVARCHAR(400)) LIKE '%admin%';
GO

CREATE SECURITY POLICY dbo.PolicyBrokerFilter
    ADD FILTER PREDICATE dbo.fn_broker_predicate(broker_oid) ON dbo.Policies
    WITH (STATE = ON);
GO

-- to switch it off again during the demo:
-- ALTER SECURITY POLICY dbo.PolicyBrokerFilter WITH (STATE = OFF);
