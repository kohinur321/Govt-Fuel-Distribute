-- ============================================================================
--  GOVERNMENT FUEL DISTRIBUTION & MONITORING SYSTEM
--  Database Design Project — DDL + DML (MS SQL Server / T-SQL)
--
--  Business rule: the country does not produce or supply fuel itself.
--  ALL fuel is IMPORTED from foreign suppliers (enforced by a CHECK constraint
--  on Supplier.country), stored in CentralStock, then ALLOCATED to stations
--  (GovtExport = allocation from central stock to a station), and finally
--  SOLD to registered vehicles (Sale).
--
--  Run this whole script once in SSMS (Execute / F5). It drops and recreates
--  the database, so it can be re-run safely.
-- ============================================================================

USE master;
GO

IF DB_ID('govt_fuel_system') IS NOT NULL
BEGIN
    ALTER DATABASE govt_fuel_system SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE govt_fuel_system;
END
GO

CREATE DATABASE govt_fuel_system;
GO

USE govt_fuel_system;
GO

-- ============================================================================
-- SECTION 1: DDL — TABLE DEFINITIONS
-- ============================================================================
-- Conversion notes (MySQL -> SQL Server):
--   * AUTO_INCREMENT            -> IDENTITY(1,1)
--   * ENGINE=InnoDB             -> removed (not applicable in SQL Server)
--   * ENUM(...)                 -> VARCHAR(n) + CHECK constraint
--   * ON UPDATE/DELETE RESTRICT -> ON DELETE NO ACTION
--   * ON UPDATE CASCADE         -> removed (SQL Server rejects it here with
--                                  "may cause cycles or multiple cascade paths";
--                                  surrogate INT identity keys are never updated)
-- ============================================================================

-- ---------- 1. FuelType ------------------------------------------------
CREATE TABLE FuelType (
    id      INT IDENTITY(1,1) PRIMARY KEY,
    name    VARCHAR(50) NOT NULL UNIQUE
);
GO

-- ---------- 2. Region ----------------------------------------------------
CREATE TABLE Region (
    id      INT IDENTITY(1,1) PRIMARY KEY,
    name    VARCHAR(100) NOT NULL UNIQUE
);
GO

-- ---------- 3. Supplier (foreign suppliers only) --------------------------
CREATE TABLE Supplier (
    id       INT IDENTITY(1,1) PRIMARY KEY,
    name     VARCHAR(150) NOT NULL,
    country  VARCHAR(80)  NOT NULL,
    CONSTRAINT ck_supplier_foreign CHECK (country <> 'Bangladesh')
);
GO

-- ---------- 4. Station -----------------------------------------------------
CREATE TABLE Station (
    id         INT IDENTITY(1,1) PRIMARY KEY,
    name       VARCHAR(150) NOT NULL,
    license    VARCHAR(50)  NOT NULL UNIQUE,
    regionId   INT NOT NULL,
    status     VARCHAR(20) NOT NULL DEFAULT 'Active'
                   CHECK (status IN ('Active','Inactive','Suspended')),
    CONSTRAINT fk_station_region FOREIGN KEY (regionId) REFERENCES Region(id)
        ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- ---------- 5. Vehicle -----------------------------------------------------
CREATE TABLE Vehicle (
    id           INT IDENTITY(1,1) PRIMARY KEY,
    regNo        VARCHAR(30)  NOT NULL UNIQUE,
    owner        VARCHAR(150) NOT NULL,
    fuelId       INT NOT NULL,
    usageLimit   DECIMAL(10,2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_vehicle_fuel FOREIGN KEY (fuelId) REFERENCES FuelType(id)
        ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- ---------- 6. Users -------------------------------------------------------
CREATE TABLE Users (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    name        VARCHAR(150) NOT NULL,
    role        VARCHAR(20) NOT NULL
                    CHECK (role IN ('Admin','RegionalOfficer','StationOperator')),
    stationId   INT NULL,
    CONSTRAINT fk_users_station FOREIGN KEY (stationId) REFERENCES Station(id)
        ON DELETE SET NULL ON UPDATE NO ACTION
);
GO

-- ---------- 7. GovtPrice ---------------------------------------------------
CREATE TABLE GovtPrice (
    id         INT IDENTITY(1,1) PRIMARY KEY,
    fuelId     INT NOT NULL,
    price      DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    fromDate   DATE NOT NULL,
    CONSTRAINT fk_govtprice_fuel FOREIGN KEY (fuelId) REFERENCES FuelType(id)
        ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- ---------- 8. GovtImport (fuel bought from foreign suppliers) -------------
CREATE TABLE GovtImport (
    id           INT IDENTITY(1,1) PRIMARY KEY,
    supplierId   INT NOT NULL,
    fuelId       INT NOT NULL,
    quantity     DECIMAL(12,2) NOT NULL CHECK (quantity > 0),
    price        DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    [date]       DATE NOT NULL,
    CONSTRAINT fk_import_supplier FOREIGN KEY (supplierId) REFERENCES Supplier(id)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT fk_import_fuel FOREIGN KEY (fuelId) REFERENCES FuelType(id)
        ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- ---------- 9. GovtExport (allocation from central stock to stations) ------
CREATE TABLE GovtExport (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    stationId   INT NOT NULL,
    fuelId      INT NOT NULL,
    quantity    DECIMAL(12,2) NOT NULL CHECK (quantity > 0),
    price       DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    [date]      DATE NOT NULL,
    CONSTRAINT fk_export_station FOREIGN KEY (stationId) REFERENCES Station(id)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT fk_export_fuel FOREIGN KEY (fuelId) REFERENCES FuelType(id)
        ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- ---------- 10. Sale ---------------------------------------------------------
CREATE TABLE Sale (
    id           INT IDENTITY(1,1) PRIMARY KEY,
    stationId    INT NOT NULL,
    vehicleId    INT NOT NULL,
    fuelId       INT NOT NULL,
    quantity     DECIMAL(10,2) NOT NULL CHECK (quantity > 0),
    price        DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    saleDateTime DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT fk_sale_station FOREIGN KEY (stationId) REFERENCES Station(id)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT fk_sale_vehicle FOREIGN KEY (vehicleId) REFERENCES Vehicle(id)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT fk_sale_fuel FOREIGN KEY (fuelId) REFERENCES FuelType(id)
        ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- ---------- 11. CentralStock ---------------------------------------------------
CREATE TABLE CentralStock (
    id       INT IDENTITY(1,1) PRIMARY KEY,
    fuelId   INT NOT NULL UNIQUE,
    stock    DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (stock >= 0),
    CONSTRAINT fk_centralstock_fuel FOREIGN KEY (fuelId) REFERENCES FuelType(id)
        ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- ---------- 12. StationStock ---------------------------------------------------
CREATE TABLE StationStock (
    id           INT IDENTITY(1,1) PRIMARY KEY,
    stationId    INT NOT NULL,
    fuelId       INT NOT NULL,
    stock        DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (stock >= 0),
    capacity     DECIMAL(12,2) NOT NULL CHECK (capacity > 0),
    CONSTRAINT fk_stationstock_station FOREIGN KEY (stationId) REFERENCES Station(id)
        ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT fk_stationstock_fuel FOREIGN KEY (fuelId) REFERENCES FuelType(id)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT uq_station_fuel UNIQUE (stationId, fuelId)
);
GO

-- ============================================================================
-- SECTION 2: DML — SAMPLE DATA (INSERT)
-- ============================================================================

-- ---------- FuelType ----------
INSERT INTO FuelType (name) VALUES
('Petrol'), ('Diesel'), ('Octane'), ('CNG');

-- ---------- Region ----------
INSERT INTO Region (name) VALUES
('Dhaka'), ('Chattogram'), ('Khulna'), ('Rajshahi');

-- ---------- Supplier (all foreign) ----------
INSERT INTO Supplier (name, country) VALUES
('Gulf Petro Trading',     'UAE'),
('EastCoast Fuel Ltd.',    'Singapore'),
('Saudi Fuel Exports',     'Saudi Arabia'),
('Indian Oil Corporation', 'India');

-- ---------- Station ----------
INSERT INTO Station (name, license, regionId, status) VALUES
('Mirpur Fuel Station',      'LIC-DHK-001', 1, 'Active'),
('Gulshan Fuel Point',       'LIC-DHK-002', 1, 'Active'),
('Agrabad Filling Station',  'LIC-CTG-001', 2, 'Active'),
('Khulna City Pump',         'LIC-KHL-001', 3, 'Active'),
('Rajshahi Highway Station', 'LIC-RAJ-001', 4, 'Suspended');

-- ---------- Vehicle ----------
INSERT INTO Vehicle (regNo, owner, fuelId, usageLimit) VALUES
('DHK-METRO-GA-1234',  'Rahim Uddin',  1, 40.00),
('DHK-METRO-KHA-5678', 'Karim Sheikh', 2, 100.00),
('CTG-METRO-GA-1111',  'Fahim Reza',   1, 35.00),
('KHL-METRO-KHA-2222', 'Nusrat Jahan', 2, 80.00),
('DHK-METRO-GA-9999',  'Salma Akter',  3, 50.00);

-- ---------- Users ----------
INSERT INTO Users (name, role, stationId) VALUES
('Anisur Rahman', 'Admin',           NULL),
('Farida Yasmin', 'RegionalOfficer', NULL),
('Jasim Uddin',   'StationOperator', 1),
('Rekha Begum',   'StationOperator', 2),
('Tanvir Ahmed',  'StationOperator', 3);

-- ---------- GovtPrice (price history: two records per fuel where revised) ----------
INSERT INTO GovtPrice (fuelId, price, fromDate) VALUES
(1, 121.50, '2026-01-01'),
(1, 125.00, '2026-07-01'),
(2, 109.00, '2026-01-01'),
(2, 112.50, '2026-07-01'),
(3, 131.00, '2026-01-01'),
(4, 65.00,  '2026-01-01');

-- ---------- GovtImport (all fuel comes from foreign suppliers) ----------
INSERT INTO GovtImport (supplierId, fuelId, quantity, price, [date]) VALUES
(1, 1, 50000.00, 120.00, '2026-08-01'),   -- Petrol <- UAE
(2, 2, 70000.00, 108.00, '2026-08-02'),   -- Diesel <- Singapore
(3, 3, 20000.00, 129.00, '2026-08-03'),   -- Octane <- Saudi Arabia
(2, 1, 30000.00, 121.00, '2026-08-15'),   -- Petrol <- Singapore
(4, 2, 10000.00, 107.50, '2026-08-20');   -- Diesel <- India

-- ---------- GovtExport (allocations from central stock to stations) ----------
INSERT INTO GovtExport (stationId, fuelId, quantity, price, [date]) VALUES
(1, 1, 8000.00, 122.00, '2026-08-05'),
(2, 1, 6000.00, 122.00, '2026-08-05'),
(3, 2, 9000.00, 110.00, '2026-08-06'),
(4, 2, 7000.00, 110.00, '2026-08-06'),
(1, 3, 3000.00, 130.00, '2026-08-07');

-- ---------- CentralStock (running national stock per fuel) ----------
INSERT INTO CentralStock (fuelId, stock) VALUES
(1, 66000.00),   -- 80000 imported - 14000 allocated
(2, 64000.00),   -- 80000 imported - 16000 allocated
(3, 17000.00),   -- 20000 imported -  3000 allocated
(4, 0.00);

-- ---------- StationStock (per-station tank levels) ----------
INSERT INTO StationStock (stationId, fuelId, stock, capacity) VALUES
(1, 1, 7200.00, 10000.00),
(2, 1, 5800.00, 8000.00),
(3, 2, 8500.00, 12000.00),
(4, 2, 6900.00, 9000.00),
(1, 3, 2950.00, 5000.00);

-- ---------- Sale ----------
INSERT INTO Sale (stationId, vehicleId, fuelId, quantity, price, saleDateTime) VALUES
(1, 1, 1, 20.00, 125.00, '2026-09-01T08:15:00'),
(1, 1, 1, 25.00, 125.00, '2026-09-05T09:00:00'),   -- pushes vehicle 1 over its 40L limit
(2, 2, 2, 60.00, 112.50, '2026-09-02T10:30:00'),
(3, 3, 1, 30.00, 125.00, '2026-09-03T14:00:00'),
(1, 5, 3, 40.00, 131.00, '2026-09-04T16:45:00');
GO

-- ============================================================================
-- SECTION 3: DML — USEFUL SELECT QUERIES (REPORTING)
-- ============================================================================

-- Q1. Current (latest) government price for every fuel type
SELECT ft.name AS fuelType, gp.price, gp.fromDate
FROM GovtPrice gp
JOIN FuelType ft ON ft.id = gp.fuelId
WHERE gp.fromDate = (
    SELECT MAX(gp2.fromDate) FROM GovtPrice gp2 WHERE gp2.fuelId = gp.fuelId
)
ORDER BY ft.name;

-- Q2. National (central) stock summary per fuel type
SELECT ft.name AS fuelType, cs.stock
FROM CentralStock cs
JOIN FuelType ft ON ft.id = cs.fuelId
ORDER BY cs.stock DESC;

-- Q3. Station stock levels with percentage of tank capacity used
SELECT s.name AS station, ft.name AS fuelType, ss.stock, ss.capacity,
       ROUND((ss.stock / ss.capacity) * 100, 1) AS pct_full
FROM StationStock ss
JOIN Station s   ON s.id = ss.stationId
JOIN FuelType ft ON ft.id = ss.fuelId
ORDER BY pct_full ASC;

-- Q4. Low-stock alert: stations below 30% tank capacity
SELECT s.name AS station, ft.name AS fuelType, ss.stock, ss.capacity,
       ROUND((ss.stock / ss.capacity) * 100, 1) AS pct_full
FROM StationStock ss
JOIN Station s   ON s.id = ss.stationId
JOIN FuelType ft ON ft.id = ss.fuelId
WHERE (ss.stock / ss.capacity) < 0.30;

-- Q5. Vehicles that have exceeded their allocated usage limit (overuse detection)
SELECT v.regNo, v.owner, ft.name AS fuelType, v.usageLimit,
       COALESCE(SUM(sl.quantity), 0) AS totalUsed,
       (COALESCE(SUM(sl.quantity), 0) - v.usageLimit) AS overBy
FROM Vehicle v
JOIN FuelType ft ON ft.id = v.fuelId
LEFT JOIN Sale sl ON sl.vehicleId = v.id
GROUP BY v.id, v.regNo, v.owner, ft.name, v.usageLimit
HAVING COALESCE(SUM(sl.quantity), 0) > v.usageLimit;

-- Q6. Total quantity and value sold, per station
SELECT s.name AS station,
       SUM(sl.quantity) AS totalLitres,
       SUM(sl.quantity * sl.price) AS totalRevenue
FROM Sale sl
JOIN Station s ON s.id = sl.stationId
GROUP BY s.id, s.name
ORDER BY totalRevenue DESC;

-- Q7. Total fuel imported per (foreign) supplier
SELECT sp.name AS supplier, sp.country, ft.name AS fuelType, SUM(gi.quantity) AS totalImported
FROM GovtImport gi
JOIN Supplier sp ON sp.id = gi.supplierId
JOIN FuelType ft ON ft.id = gi.fuelId
GROUP BY sp.id, sp.name, sp.country, ft.name
ORDER BY totalImported DESC;

-- Q8. Total fuel allocated (GovtExport) to each station
SELECT s.name AS station, ft.name AS fuelType, SUM(ge.quantity) AS totalAllocated
FROM GovtExport ge
JOIN Station s   ON s.id = ge.stationId
JOIN FuelType ft ON ft.id = ge.fuelId
GROUP BY s.id, s.name, ft.name
ORDER BY totalAllocated DESC;

-- Q9. Number of active stations per region
SELECT r.name AS region, COUNT(s.id) AS activeStations
FROM Region r
LEFT JOIN Station s ON s.regionId = r.id AND s.status = 'Active'
GROUP BY r.id, r.name;

-- Q10. Users with the station they are assigned to
SELECT u.name AS userName, u.role, COALESCE(s.name, 'Head Office') AS station
FROM Users u
LEFT JOIN Station s ON s.id = u.stationId
ORDER BY u.role;

-- Q11. Full sales detail report (station, vehicle, fuel, amount)
SELECT sl.id, s.name AS station, v.regNo, v.owner, ft.name AS fuelType,
       sl.quantity, sl.price, (sl.quantity * sl.price) AS amount, sl.saleDateTime
FROM Sale sl
JOIN Station s   ON s.id = sl.stationId
JOIN Vehicle v   ON v.id = sl.vehicleId
JOIN FuelType ft ON ft.id = sl.fuelId
ORDER BY sl.saleDateTime DESC;

-- Q12. Daily sales total (for a chart / dashboard)
SELECT CAST(saleDateTime AS DATE) AS saleDate,
       SUM(quantity) AS litresSold,
       SUM(quantity * price) AS revenue
FROM Sale
GROUP BY CAST(saleDateTime AS DATE)
ORDER BY saleDate;

-- Q13. Price history / trend for a specific fuel type (e.g., Petrol, fuelId = 1)
SELECT price, fromDate
FROM GovtPrice
WHERE fuelId = 1
ORDER BY fromDate;

-- Q14. Suspended or inactive stations (compliance check)
SELECT name, license, status FROM Station WHERE status <> 'Active';

-- Q15. Import by country: how much of each fuel came from which foreign country
SELECT sp.country, ft.name AS fuelType, SUM(gi.quantity) AS totalImported,
       AVG(gi.price) AS avgImportPrice
FROM GovtImport gi
JOIN Supplier sp ON sp.id = gi.supplierId
JOIN FuelType ft ON ft.id = gi.fuelId
GROUP BY sp.country, ft.name
ORDER BY totalImported DESC;

-- ============================================================================
-- SECTION 4: DML — UPDATE STATEMENTS
-- ============================================================================

-- U1. Add newly imported fuel to central stock (after a GovtImport is recorded)
UPDATE CentralStock
SET stock = stock + 30000.00
WHERE fuelId = 1;

-- U2. Move fuel from central stock to a station's tank (after a GovtExport)
UPDATE CentralStock SET stock = stock - 5000.00 WHERE fuelId = 2;
UPDATE StationStock SET stock = stock + 5000.00 WHERE stationId = 3 AND fuelId = 2;

-- U3. Deduct sold fuel from a station's tank (after a Sale)
UPDATE StationStock
SET stock = stock - 20.00
WHERE stationId = 1 AND fuelId = 1;

-- U4. Update a vehicle's approved usage limit
UPDATE Vehicle SET usageLimit = 45.00 WHERE regNo = 'DHK-METRO-GA-1234';

-- U5. Suspend a station found violating regulations
UPDATE Station SET status = 'Suspended' WHERE id = 2;

-- U6. Revise the government price for a fuel type effective a new date
UPDATE GovtPrice SET price = 128.00 WHERE fuelId = 1 AND fromDate = '2026-07-01';

-- ============================================================================
-- SECTION 5: DML — DELETE STATEMENTS
-- ============================================================================

-- D1. Remove a vehicle that is no longer registered (must have no Sale history)
DELETE FROM Vehicle WHERE regNo = 'KHL-METRO-KHA-2222';

-- D2. Remove a mistakenly entered sale record
DELETE FROM Sale WHERE id = 5;

-- D3. Remove an incorrectly entered import record (safe: nothing references GovtImport)
DELETE FROM GovtImport WHERE id = 4;

-- Note: FK constraints use NO ACTION on most parent tables, so the statement
-- below is intentionally BLOCKED — you cannot delete a Supplier while GovtImport
-- rows still reference it (referential integrity protects the import history):
--   DELETE FROM Supplier WHERE id = 1;
--   -- fails with: "The DELETE statement conflicted with the REFERENCE constraint
--   --              fk_import_supplier"

-- Note: the CHECK constraint below is also intentionally BLOCKED — domestic
-- suppliers are not allowed because all fuel is imported:
--   INSERT INTO Supplier (name, country) VALUES ('Local Oil Co', 'Bangladesh');
--   -- fails with: "The INSERT statement conflicted with the CHECK constraint
--   --              ck_supplier_foreign"
GO

-- ============================================================================
-- SECTION 6 (BONUS): VIEWS for quick dashboard access
-- ============================================================================
-- CREATE OR ALTER VIEW needs SQL Server 2016 SP1+. Each must be alone in its batch.

CREATE OR ALTER VIEW vw_CurrentPrices AS
SELECT ft.name AS fuelType, gp.price, gp.fromDate
FROM GovtPrice gp
JOIN FuelType ft ON ft.id = gp.fuelId
WHERE gp.fromDate = (SELECT MAX(gp2.fromDate) FROM GovtPrice gp2 WHERE gp2.fuelId = gp.fuelId);
GO

CREATE OR ALTER VIEW vw_LowStockStations AS
SELECT s.name AS station, ft.name AS fuelType, ss.stock, ss.capacity,
       ROUND((ss.stock/ss.capacity)*100,1) AS pct_full
FROM StationStock ss
JOIN Station s ON s.id = ss.stationId
JOIN FuelType ft ON ft.id = ss.fuelId
WHERE (ss.stock/ss.capacity) < 0.30;
GO

CREATE OR ALTER VIEW vw_VehicleOveruse AS
SELECT v.regNo, v.owner, ft.name AS fuelType, v.usageLimit,
       COALESCE(SUM(sl.quantity),0) AS totalUsed
FROM Vehicle v
JOIN FuelType ft ON ft.id = v.fuelId
LEFT JOIN Sale sl ON sl.vehicleId = v.id
GROUP BY v.id, v.regNo, v.owner, ft.name, v.usageLimit
HAVING COALESCE(SUM(sl.quantity),0) > v.usageLimit;
GO

CREATE OR ALTER VIEW vw_ImportsByCountry AS
SELECT sp.country, ft.name AS fuelType, SUM(gi.quantity) AS totalImported
FROM GovtImport gi
JOIN Supplier sp ON sp.id = gi.supplierId
JOIN FuelType ft ON ft.id = gi.fuelId
GROUP BY sp.country, ft.name;
GO

-- ============================================================================
-- END OF SCRIPT
-- ============================================================================
