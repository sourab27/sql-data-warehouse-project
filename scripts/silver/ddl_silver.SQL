/*
****************************************************************************************************************
DDL SCRIPT : Create Silver Tables                                                                              *
****************************************************************************************************************
Script Purpose :                                                                                               *
       This Script Creates Table In the 'silver' schema  , dropping existing tables                            *
Run this script to redefine the DDL Structure of Bronze layer.                                                 *
                                                                                                               *
****************************************************************************************************************

CREATE SCHEMA silver;


IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_cust_info;
GO

CREATE TABLE silver.crm_cust_info (
    cst_id               INT,
    cst_key              NVARCHAR(50),
    cst_firstname        NVARCHAR(50),
    cst_lastname         NVARCHAR(50),
    cst_marital_status   NVARCHAR(50),
    cst_gndr             NVARCHAR(50),
    cst_create_date      DATE,
    dwh_create_date      DATETIME2 DEFAULT GETDATE()
);

IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_prd_info;
GO

CREATE TABLE silver.crm_prd_info (
    prd_id        INT,
    prd_key       NVARCHAR(50),
    prd_nm        NVARCHAR(50),
    prd_cost      INT,
    prd_line      NVARCHAR(50),
    prd_start_dt  DATETIME,
    prd_end_dt    DATETIME,
	dwh_create_date      DATETIME2 DEFAULT GETDATE()
	
);


IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE silver.crm_sales_details;
CREATE TABLE silver.crm_sales_details (
    sls_ord_num   NVARCHAR(50),
    sls_prd_key   NVARCHAR(50),
    sls_cust_id   INT,
    sls_order_dt  DATE,
    sls_ship_dt   DATE,
    sls_due_dt    DATE,
    sls_sales     INT,
    sls_quantity  INT,
    sls_price     INT,
	dwh_create_date      DATETIME2 DEFAULT GETDATE()
	
);

IF OBJECT_ID('silver.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE silver.erp_loc_a101;
GO

CREATE TABLE silver.erp_loc_a101 (
    cid              NVARCHAR(50),
    cntry            NVARCHAR(50),
    dwh_create_date  DATETIME2 DEFAULT GETDATE()
);

IF OBJECT_ID('silver.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE silver.erp_cust_az12;
GO

CREATE TABLE silver.erp_cust_az12 (
    cid              NVARCHAR(50),
    bdate            DATE,
    gen              NVARCHAR(50),
    dwh_create_date  DATETIME2 DEFAULT GETDATE()
);

IF OBJECT_ID('silver.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE silver.erp_px_cat_g1v2;
GO

CREATE TABLE silver.erp_px_cat_g1v2 (
    id           NVARCHAR(50),
    cat          NVARCHAR(50),
    subcat       NVARCHAR(50),
    maintenance  NVARCHAR(50),
	dwh_create_date  DATETIME2 DEFAULT GETDATE()
);


----------------------------------------------------------------------------
------------- sls_order_dt -------------------------------------------------
----------------------------------------------------------------------------

INSERT INTO silver.crm_sales_details (
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    sls_sales,
    sls_quantity,
    sls_price
)

SELECT
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
   sls_order_dt,
    sls_ship_dt,
    sls_due_dt,

    CASE WHEN sls_sales IS NULL OR sls_sales < = 0 OR sls_sales != sls_quantity * ABS(sls_price)
     THEN sls_quantity * ABS(sls_price) 
  ELSE sls_sales
  END AS sls_sales ,

    sls_quantity,
CASE WHEN sls_price IS NULL OR sls_price < = 0
    THEN sls_sales / NULLIF(sls_quantity , 0)
ELSE sls_price 
END AS sls_price

FROM bronze.crm_sales_details;

SELECT * FROM silver.crm_sales_details;
----------------------------------------------------------------------------------------------------------
-- data testing --
-- check for Nulls or Duplicates in Primary Key
-- Expectation : No Result
SELECT  cst_id , COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;


 


-- Check for unwanted spaces
-- No Results

SELECT cst_firstname
FROM silver.crm_cust_info
WHERE cst_firstname ! = TRIM(cst_firstname )

-------------------------
-- Check for unwanted spaces
-- No Results

SELECT cst_lastname
FROM silver.crm_cust_info
WHERE cst_lastname ! = TRIM(cst_lastname )
----------------------------------------------------------------------------------

-- Data Standardization And Consistency
SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info

---------------------------------------------------------------------------------------------------------------------------
-- sub query 

SELECT* FROM  (
SELECT *,ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
FROM silver.crm_cust_info)t WHERE flag_last = 1

----------------------------------------------------------------------------------------------------------------------------------

-- New query with above sub queries


INSERT INTO silver.crm_cust_info(
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date)

SELECT
    cst_id,
    cst_key,
    TRIM(cst_firstname) AS cst_firstname,
    TRIM(cst_lastname) AS cst_lastname,
    
    CASE 
        WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
        WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
        ELSE 'N/A'
    END AS cst_marital_status,
    
    CASE 
        WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
        WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
        ELSE 'N/A'
    END AS cst_gndr,
    
    cst_create_date
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
    FROM bronze.crm_cust_info
) t
WHERE flag_last = 1;



-- queries for third CRM table 
--  Check For Invalid Dates
SELECT 
NULLIF(sls_order_dt,0)sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt IS 

SELECT * FROM bronze.crm_sales_details
WHERE sls_ship_dt IS NULL

--- Check For Invalid Date Orders----------------
SELECT *
FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt
-----------------------------------------------------------------------------------------------------------------
-- Check Data Consistency: Between Sales, Quantity, and Price
-- >> Sales = Quantity * Price
-- >> Values must not be NULL, zero, or negative.

SELECT 
    sls_sales AS old_sls_sales , 
    sls_quantity,
    sls_price as old_sls_price,
CASE WHEN sls_sales IS NULL OR sls_sales < = 0 OR sls_sales! = sls_quantity * ABS(sls_price)
     THEN sls_quantity * ABS(sls_price) 
  ELSE sls_sales
END AS sls_sales ,

CASE WHEN sls_price IS NULL OR sls_price < = 0
    THEN sls_sales / NULLIF(sls_quantity , 0)
ELSE sls_price 
END AS sls_price

FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
    OR sls_sales IS NULL
    OR sls_quantity IS NULL
    OR sls_price IS NULL
    OR sls_sales <= 0
    OR sls_quantity <= 0
    OR sls_price <= 0
     ;
