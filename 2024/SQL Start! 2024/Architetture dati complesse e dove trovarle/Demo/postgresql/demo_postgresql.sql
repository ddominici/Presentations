/*
 * PostgreSQL su Docker
 */

--ALTER DATABASE orderdb SET search_path TO purchaseorder;

select * from purchaseorder."src_testDB_dbo_orders" 
order by id desc;


select * from purchaseorder."src_testDB_dbo_products" 
order by id limit 5;




/*
CREATE OR REPLACE VIEW purchaseorder.v_products
 AS
 SELECT id,
    name,
    description,
    weight
   FROM purchaseorder."src_testDB_dbo_products";

ALTER TABLE purchaseorder.v_products
    OWNER TO orderuser;
*/

select * from v_products vp 