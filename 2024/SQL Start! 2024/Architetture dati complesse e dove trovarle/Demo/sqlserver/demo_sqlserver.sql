/*
 * SQL Server su Docker
 */

SELECT * FROM orders order by id desc;


INSERT INTO orders VALUES ('2024-06-06', 1001, 10, 105)

-- Update
UPDATE products SET weight = weight * 1.10 WHERE id = 101

-- Delete
DELETE orders WHERE id = 10006

