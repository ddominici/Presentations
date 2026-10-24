/*  Demo 2 — link a broker row to a real Microsoft Entra user.
    @claims.oid in the DAB item-level policy is the token's object id claim.
    Replace the GUIDs with the object ids of your demo accounts.  */



CREATE USER sqlcon WITH PASSWORD ='<your-password>';

EXEC sp_addrolemember 'db_datareader', 'sqlcon'

/*
DECLARE @broker_oid UNIQUEIDENTIFIER = '330d838a-6dff-4840-bd2c-88fb2822b2ba';  -- broker demo user

UPDATE dbo.Brokers  SET entra_oid  = @broker_oid WHERE code = 'BRK-MI-01';
UPDATE dbo.Policies SET broker_oid = @broker_oid WHERE broker_id = 1;
GO

SELECT code, name, entra_oid FROM dbo.Brokers;
SELECT policy_number, broker_id, broker_oid FROM dbo.Policies;
GO
*/