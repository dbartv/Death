#Step 1: Create a database called 'Demo'
#Step 2: Create a table called 'Employee' with the following columns: 'EmployeeID', 'EmployeeName', 'EmployeeSalary', 'EmployeeDepartment', 'EmployeePosition'
#EmployeeID: int, primary key, auto increment
#Step 3: Insert 1000 rows into the 'Employee' table, do this in 1 statement without user input
#Step 4: Make a duplicate index on EmployeeName
#Step 5: Create a index on EmployeeName, EmployeeSalary
#Start
CREATE DATABASE Demo;
USE Demo;
CREATE TABLE Employee (
    EmployeeID int PRIMARY KEY AUTO_INCREMENT,
    EmployeeName varchar(255),
    EmployeeSalary int,
    EmployeeDepartment varchar(255),
    EmployeePosition varchar(255)
);

-- Step 1: Create a database called 'Demo'
CREATE DATABASE Demo;
USE Demo;

-- Step 2: Create a table called 'Employee' with the specified columns
CREATE TABLE Employee (
    EmployeeID int PRIMARY KEY AUTO_INCREMENT,
    EmployeeName varchar(255),
    EmployeeSalary int,
    EmployeeDepartment varchar(255),
    EmployeePosition varchar(255)
);

-- Step 3: Insert 1000 rows into the 'Employee' table in one statement without user input
INSERT INTO Employee (EmployeeName, EmployeeSalary, EmployeeDepartment, EmployeePosition)
SELECT TOP 1000 
    'EmployeeName' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(10)),
    50000,
    'Department1',
    'Position1'
FROM sys.objects a
CROSS JOIN sys.objects b;

-- Step 4: Make a duplicate index on EmployeeName
-- This step is not valid as SQL Server does not allow duplicate indexes on the same column.
-- Instead, we will create a single index on EmployeeName.

-- Step 5: Create an index on EmployeeName, EmployeeSalary
CREATE INDEX idx_EmployeeName_EmployeeSalary ON Employee (EmployeeName, EmployeeSalary);
#SQL server allows duplicate indexes. Please create a duplicate index on EmployeeName
CREATE INDEX idx_EmployeeName_Duplicate ON Employee (EmployeeName);

