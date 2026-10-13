-- ============================================================================
--  DEMO QUERIES — run AFTER govt_fuel_system.sql
--  Select ONE block at a time (mouse select) and press F5, in this order.
-- ============================================================================
USE govt_fuel_system;
GO

-- FEATURE 1: Fuel is imported only from foreign countries
SELECT * FROM vw_ImportsByCountry ORDER BY totalImported DESC;

-- FEATURE 2: Import records with supplier and country
SELECT sp.name AS supplier, sp.country, ft.name AS fuel, gi.quantity, gi.price, gi.[date]
FROM GovtImport gi
JOIN Supplier sp ON sp.id = gi.supplierId
JOIN FuelType ft ON ft.id = gi.fuelId
ORDER BY gi.[date];

-- FEATURE 3: National (central) stock
SELECT ft.name AS fuel, cs.stock
FROM CentralStock cs JOIN FuelType ft ON ft.id = cs.fuelId;

-- FEATURE 4: Allocation from central stock to stations
SELECT s.name AS station, ft.name AS fuel, SUM(ge.quantity) AS totalAllocated
FROM GovtExport ge
JOIN Station s ON s.id = ge.stationId
JOIN FuelType ft ON ft.id = ge.fuelId
GROUP BY s.name, ft.name
ORDER BY totalAllocated DESC;

-- FEATURE 5: Station tank levels (% full)
SELECT s.name AS station, ft.name AS fuel, ss.stock, ss.capacity,
       ROUND(ss.stock / ss.capacity * 100, 1) AS pct_full
FROM StationStock ss
JOIN Station s ON s.id = ss.stationId
JOIN FuelType ft ON ft.id = ss.fuelId
ORDER BY pct_full;

-- FEATURE 6: Current government price and price history
SELECT * FROM vw_CurrentPrices;
SELECT ft.name AS fuel, gp.price, gp.fromDate
FROM GovtPrice gp JOIN FuelType ft ON ft.id = gp.fuelId
ORDER BY ft.name, gp.fromDate;

-- FEATURE 7: Sales to vehicles, and revenue per station
SELECT sl.id, s.name AS station, v.regNo, v.owner, ft.name AS fuel,
       sl.quantity, sl.price, sl.quantity * sl.price AS amount, sl.saleDateTime
FROM Sale sl
JOIN Station s ON s.id = sl.stationId
JOIN Vehicle v ON v.id = sl.vehicleId
JOIN FuelType ft ON ft.id = sl.fuelId
ORDER BY sl.saleDateTime;

SELECT s.name AS station, SUM(sl.quantity) AS totalLitres, SUM(sl.quantity * sl.price) AS totalRevenue
FROM Sale sl JOIN Station s ON s.id = sl.stationId
GROUP BY s.name
ORDER BY totalRevenue DESC;

-- FEATURE 8: Vehicle overuse detection
-- (the main script's U4 raised this limit to 45; set it back to 40 for the demo)
UPDATE Vehicle SET usageLimit = 40 WHERE regNo = 'DHK-METRO-GA-1234';
SELECT * FROM vw_VehicleOveruse;

-- FEATURE 9: Compliance — suspended / inactive stations
SELECT name, license, status FROM Station WHERE status <> 'Active';

-- FEATURE 10: Users and their roles
SELECT u.name, u.role, COALESCE(s.name, 'Head Office') AS station
FROM Users u LEFT JOIN Station s ON s.id = u.stationId
ORDER BY u.role;

-- FEATURE 11: Data integrity — these two MUST fail (run one at a time, show Messages tab)
-- 11a. Domestic supplier is blocked by CHECK constraint ck_supplier_foreign
INSERT INTO Supplier (name, country) VALUES ('Local Oil Co', 'Bangladesh');

-- 11b. Supplier with import history cannot be deleted (FOREIGN KEY fk_import_supplier)
DELETE FROM Supplier WHERE id = 1;
