/*
 * SQL Start! 2024
 *
 * Demo Debezium
 *
 */

USE testDB
GO

SELECT * FROM products
SELECT * FROM orders

-- Insert
INSERT INTO orders VALUES ('2024-06-06', 1001, 10, 105)

-- Update
UPDATE products SET weight = weight * 1.10 WHERE id = 101

-- Delete
DELETE orders WHERE id = 12005

