DELETE FROM Policies;
DELETE FROM Brokers;

INSERT INTO Brokers (id, code, name, city, entra_oid) overriding system value VALUES
 (1, 'BRK-MI-01', N'Assicurazioni Navigli',   N'Ancona',  NULL),
 (2, 'BRK-RM-02', N'Tevere Broker',           N'Tivoli',    NULL),
 (3, 'BRK-TO-03', N'Mole Insurance Partners', N'Vercelli',  NULL),
 (4, 'BRK-NA-04', N'Partenope Risk',          N'Catania',  NULL);

INSERT INTO Policies
 (policy_number, product, status, premium, commission_amount, broker_id, effective_date, expiry_date)
overriding system value VALUES
 ('POL-2026-0001', N'Motor - comprehensive',  'active',    1420.00, 142.00, 1, '2026-01-15', '2027-01-14'),
 ('POL-2026-0002', N'Home - fire and theft',  'active',     380.50,  38.05, 1, '2026-02-01', '2027-01-31'),
 ('POL-2026-0003', N'Motor - third party',    'lapsed',     610.00,  61.00, 2, '2025-03-10', '2026-03-09'),
 ('POL-2026-0004', N'Travel - annual',        'active',     215.00,  21.50, 2, '2026-04-01', '2027-03-31'),
 ('POL-2026-0005', N'Professional indemnity', 'pending',   2850.00, 285.00, 3, '2026-05-20', '2027-05-19'),
 ('POL-2026-0006', N'Home - all risks',       'active',     940.75,  94.08, 3, '2026-06-01', '2027-05-31'),
 ('POL-2026-0007', N'Motor - fleet',          'active',    7300.00, 730.00, 4, '2026-01-02', '2027-01-01'),
 ('POL-2026-0008', N'Cyber - SME',            'cancelled', 1180.00, 118.00, 4, '2025-11-11', '2026-11-10');

SELECT * FROM Brokers;
SELECT * FROM Policies;

