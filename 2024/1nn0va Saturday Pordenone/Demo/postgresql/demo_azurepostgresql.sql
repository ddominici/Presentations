/*
 * PostgreSQL Flexible Server on Azure
 */

/*
CREATE SCHEMA purchaseorder;

ALTER DATABASE orderdb SET search_path TO purchaseorder;

GRANT ALL PRIVILEGES ON DATABASE orderdb TO orderuser;

GRANT ALL PRIVILEGES ON SCHEMA purchaseorder TO orderuser;

GRANT CONNECT ON DATABASE orderdb TO orderuser;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA purchaseorder TO orderuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA purchaseorder TO orderuser;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA purchaseorder TO orderuser;
*/

select * from purchaseorder."src_testDB_dbo_orders";