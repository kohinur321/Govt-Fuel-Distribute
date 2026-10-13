# Government Fuel Distribution & Monitoring System

A database design course project (MS SQL Server / T-SQL).

The country does not produce fuel, so **all fuel is imported from foreign suppliers**.
The system tracks imports, national stock, allocation to stations, vehicle-wise sales and
government prices.

## How fuel flows through the system

1. **Import** (`GovtImport`) from a foreign `Supplier` -> `CentralStock` increases
2. **Allocation** (`GovtExport`) from central stock to a `Station` -> `StationStock` increases
3. **Sale** (`Sale`) from a station to a registered `Vehicle` (checked against `usageLimit`)

## Database

- File: [`database/govt_fuel_system.sql`](database/govt_fuel_system.sql)
- Contains: DDL (12 tables), sample data (INSERT), 15 reporting queries (SELECT),
  UPDATE and DELETE examples, and 4 views.

| Table | Purpose |
|---|---|
| FuelType | Petrol, Diesel, Octane, CNG |
| Region | Dhaka, Chattogram, Khulna, Rajshahi |
| Supplier | Foreign suppliers only (`CHECK country <> 'Bangladesh'`) |
| Station | Fuel stations with license, region, status |
| Vehicle | Registered vehicles with fuel type and usage limit |
| Users | Admin, RegionalOfficer, StationOperator |
| GovtPrice | Price history per fuel |
| GovtImport | Fuel imported from foreign suppliers |
| GovtExport | Allocation from central stock to stations |
| Sale | Fuel sold to vehicles |
| CentralStock | National stock per fuel |
| StationStock | Tank level and capacity per station and fuel |

### How to run

1. Open **SQL Server Management Studio (SSMS)** and connect to your server.
2. Open `database/govt_fuel_system.sql`.
3. Press **Execute (F5)**. The script drops and recreates `govt_fuel_system`, so it can be re-run.
4. Query it, for example:

```sql
USE govt_fuel_system;
SELECT * FROM vw_ImportsByCountry;
SELECT * FROM vw_VehicleOveruse;
SELECT * FROM vw_CurrentPrices;
```

Requires SQL Server 2016 SP1 or later (`CREATE OR ALTER VIEW`).

## Frontend (optional)

`frontend/index.html` is a static Tailwind CSS dashboard showing the sample data
(no server needed, just open it in a browser; internet is required for Tailwind CDN).

## Repository structure

```
.
├── README.md
├── database/
│   └── govt_fuel_system.sql
└── frontend/
    └── index.html
```


-- ============================================================================
--  GOVERNMENT FUEL DISTRIBUTION & MONITORING SYSTEM  (MS SQL Server / T-SQL)
--  All fuel is IMPORTED from foreign suppliers (CHECK on Supplier.country).
--  Flow: Import -> CentralStock -> Allocation (GovtExport) -> Sale
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
-- SECTION 1: DDL — TABLES
-- ============================================================================

CREATE TABLE FuelType (
    id      INT IDENTITY(1,1) PRIMARY KEY,
    name    VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE Region (
    id      INT IDENTITY(1,1) PRIMARY KEY,
    name    VARCHAR(100) NOT NULL UNIQUE
);
GO

CREATE TABLE Supplier (
    id       INT IDENTITY(1,1) PRIMARY KEY,
    name     VARCHAR(150) NOT NULL,
    country  VARCHAR(80)  NOT NULL,
    CONSTRAINT ck_supplier_foreign CHECK (country <> 'Bangladesh')
);
GO

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

CREATE TABLE GovtPrice (
    id         INT IDENTITY(1,1) PRIMARY KEY,
    fuelId     INT NOT NULL,
    price      DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    fromDate   DATE NOT NULL,
    CONSTRAINT fk_govtprice_fuel FOREIGN KEY (fuelId) REFERENCES FuelType(id)
        ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

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

-- GovtExport = allocation from central stock to a station
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

CREATE TABLE CentralStock (
    id       INT IDENTITY(1,1) PRIMARY KEY,
    fuelId   INT NOT NULL UNIQUE,
    stock    DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (stock >= 0),
    CONSTRAINT fk_centralstock_fuel FOREIGN KEY (fuelId) REFERENCES FuelType(id)
        ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

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
-- SECTION 2: DML — INSERT (sample data)
-- ============================================================================

INSERT INTO FuelType (name) VALUES
('Petrol'), ('Diesel'), ('Octane'), ('CNG');

INSERT INTO Region (name) VALUES
('Dhaka'), ('Chattogram'), ('Khulna'), ('Rajshahi');

INSERT INTO Supplier (name, country) VALUES
('Gulf Petro Trading',     'UAE'),
('EastCoast Fuel Ltd.',    'Singapore'),
('Saudi Fuel Exports',     'Saudi Arabia'),
('Indian Oil Corporation', 'India');

INSERT INTO Station (name, license, regionId, status) VALUES
('Mirpur Fuel Station',      'LIC-DHK-001', 1, 'Active'),
('Gulshan Fuel Point',       'LIC-DHK-002', 1, 'Active'),
('Agrabad Filling Station',  'LIC-CTG-001', 2, 'Active'),
('Khulna City Pump',         'LIC-KHL-001', 3, 'Active'),
('Rajshahi Highway Station', 'LIC-RAJ-001', 4, 'Suspended');

INSERT INTO Vehicle (regNo, owner, fuelId, usageLimit) VALUES
('DHK-METRO-GA-1234',  'Rahim Uddin',  1, 40.00),
('DHK-METRO-KHA-5678', 'Karim Sheikh', 2, 100.00),
('CTG-METRO-GA-1111',  'Fahim Reza',   1, 35.00),
('KHL-METRO-KHA-2222', 'Nusrat Jahan', 2, 80.00),
('DHK-METRO-GA-9999',  'Salma Akter',  3, 50.00);

INSERT INTO Users (name, role, stationId) VALUES
('Anisur Rahman', 'Admin',           NULL),
('Farida Yasmin', 'RegionalOfficer', NULL),
('Jasim Uddin',   'StationOperator', 1),
('Rekha Begum',   'StationOperator', 2),
('Tanvir Ahmed',  'StationOperator', 3);

INSERT INTO GovtPrice (fuelId, price, fromDate) VALUES
(1, 121.50, '2026-01-01'),
(1, 125.00, '2026-07-01'),
(2, 109.00, '2026-01-01'),
(2, 112.50, '2026-07-01'),
(3, 131.00, '2026-01-01'),
(4, 65.00,  '2026-01-01');

INSERT INTO GovtImport (supplierId, fuelId, quantity, price, [date]) VALUES
(1, 1, 50000.00, 120.00, '2026-08-01'),   -- Petrol <- UAE
(2, 2, 70000.00, 108.00, '2026-08-02'),   -- Diesel <- Singapore
(3, 3, 20000.00, 129.00, '2026-08-03'),   -- Octane <- Saudi Arabia
(2, 1, 30000.00, 121.00, '2026-08-15'),   -- Petrol <- Singapore
(4, 2, 10000.00, 107.50, '2026-08-20');   -- Diesel <- India

INSERT INTO GovtExport (stationId, fuelId, quantity, price, [date]) VALUES
(1, 1, 8000.00, 122.00, '2026-08-05'),
(2, 1, 6000.00, 122.00, '2026-08-05'),
(3, 2, 9000.00, 110.00, '2026-08-06'),
(4, 2, 7000.00, 110.00, '2026-08-06'),
(1, 3, 3000.00, 130.00, '2026-08-07');

INSERT INTO CentralStock (fuelId, stock) VALUES
(1, 66000.00),   -- 80000 imported - 14000 allocated
(2, 64000.00),   -- 80000 imported - 16000 allocated
(3, 17000.00),   -- 20000 imported -  3000 allocated
(4, 0.00);

INSERT INTO StationStock (stationId, fuelId, stock, capacity)