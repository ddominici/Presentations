-- View: purchaseorder.v_products

-- DROP VIEW purchaseorder.v_products;

CREATE OR REPLACE VIEW purchaseorder.v_products
 AS
 SELECT id,
    name,
    description,
    weight
   FROM purchaseorder."src_testDB_dbo_products";

ALTER TABLE purchaseorder.v_products
    OWNER TO orderuser;