-- =====================================================
-- 7RIVERS NATIONAL BANK - DEMO ENVIRONMENT SETUP
-- =====================================================
--
-- This script sets up a complete banking demo environment featuring:
-- - Customer, account, and transaction data
-- - Credit card and loan management
-- - Branch and geography dimensions
-- - Customer service representative (CSR) interaction tracking
-- - Cortex AI Search services for call center logs and marketing documents
-- - Snowflake Intelligence Agent for conversational analytics
--
-- PREREQUISITES:
-- - Run this script as ACCOUNTADMIN role
-- - Ensure access to Azure external stage for data loading
-- - Snowflake Intelligence features must be enabled on your account
--
-- =====================================================

-- =====================================================
-- SECTION 1: ROLE AND PERMISSIONS SETUP
-- =====================================================

-- Run this script as ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;

-- Create the role
CREATE ROLE IF NOT EXISTS BANKING_DEMO_7RIVERS_ROLE
    COMMENT = 'Role for Banking Demo with permissions for database, schemas, warehouse, cortex agent, and semantic views';

-- Grant the role to SYSADMIN (so you can assume it)
GRANT ROLE BANKING_DEMO_7RIVERS_ROLE TO ROLE SYSADMIN;

-- Grant privileges to create database
GRANT CREATE DATABASE ON ACCOUNT TO ROLE BANKING_DEMO_7RIVERS_ROLE;

-- Grant privileges to create warehouse
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE BANKING_DEMO_7RIVERS_ROLE;

-- Grant Snowflake Cortex AI capabilities to the role for LLM and ML functions
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE BANKING_DEMO_7RIVERS_ROLE;

-- Optional: Grant to specific users
-- GRANT ROLE BANKING_DEMO_7RIVERS_ROLE TO USER <username>;

-- Grant access to Snowflake Intelligence for AI agent capabilities
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_INTELLIGENCE.AGENTS;
GRANT USAGE ON DATABASE SNOWFLAKE_INTELLIGENCE TO ROLE BANKING_DEMO_7RIVERS_ROLE;
GRANT USAGE ON SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS TO ROLE BANKING_DEMO_7RIVERS_ROLE;
GRANT CREATE AGENT ON SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS TO ROLE BANKING_DEMO_7RIVERS_ROLE;

-- Create email notification integration for agent alerts and notifications
CREATE NOTIFICATION INTEGRATION IF NOT EXISTS BANKING_DEMO_7RIVERS_EMAIL_INTEGRATION
  TYPE=EMAIL
  ENABLED=TRUE
  DEFAULT_SUBJECT = 'Snowflake Intelligence';

GRANT USAGE ON INTEGRATION BANKING_DEMO_7RIVERS_EMAIL_INTEGRATION TO ROLE BANKING_DEMO_7RIVERS_ROLE;

-- =====================================================
-- SECTION 2: DATABASE, SCHEMA, AND WAREHOUSE CREATION
-- =====================================================

USE ROLE BANKING_DEMO_7RIVERS_ROLE;

-- Create database and schema for banking demo data warehouse
CREATE DATABASE IF NOT EXISTS BANKING_DEMO_7RIVERS_DB;
CREATE SCHEMA IF NOT EXISTS BANKING_DEMO_7RIVERS_DB.DW; 

create or replace warehouse BANKING_DEMO_7RIVERS_WH
with
	warehouse_type='STANDARD'
	resource_constraint='STANDARD_GEN_2'
	warehouse_size='Small'
	auto_suspend=60
	auto_resume=TRUE
;

-- =====================================================
-- SECTION 3: EXTERNAL STAGE AND TABLE DEFINITIONS
-- =====================================================

-- External stage pointing to Azure blob storage with demo data files
CREATE OR REPLACE STAGE BANKING_DEMO_7RIVERS_EXT_STAGE
  URL = 'azure://public7rivers.blob.core.windows.net/banking-demo/'
;

-- =====================================================
-- STAGING TABLES
-- =====================================================
-- Staging tables for initial data ingestion before transformation

create or replace TABLE STG_CALL_CENTER_LOG (
    CALL_ID VARCHAR(50),
    REP_ID VARCHAR(50),
    REP_NAME VARCHAR(100),
    CUSTOMER_ID NUMBER,
    CUSTOMER_NAME VARCHAR(200),
    CUSTOMER_EMAIL VARCHAR(255),
    CALL_DATETIME TIMESTAMP,
    CALL_DESCRIPTION VARCHAR(500),
    CALL_TRANSCRIPT TEXT,
    LOAD_TIMESTAMP TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)COMMENT='The table contains raw records of customer interactions, specifically calls, with customer service representatives. Each record represents a single interaction and includes details about the customer, the interaction itself, and the full call transcript.'
;

create or replace TABLE STG_CHUNK_MARKETING_DOCUMENTS (
	RELATIVE_PATH VARCHAR(16777216),
	FILE_URL VARCHAR(16777216),
	CHUNK VARCHAR(16777216),
	LANGUAGE VARCHAR(7)
);

-- =====================================================
-- DIMENSION TABLES
-- =====================================================

create or replace TABLE DIM_GEOGRAPHY (
	GEOGRAPHY_KEY NUMBER(38,0),
	CITY_NAME VARCHAR(16777216) NOT NULL,
	STATE_CODE VARCHAR(16777216),
	STATE_NAME VARCHAR(16777216),
	REGION_NAME VARCHAR(16777216),
	COUNTRY_CODE VARCHAR(16777216) DEFAULT 'US',
	COUNTRY_NAME VARCHAR(16777216) DEFAULT 'United States',
	CREATED_TIMESTAMP TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	primary key (GEOGRAPHY_KEY)
)COMMENT='The table contains records of geographic locations, specifically cities and regions. Each record includes details about the location''s name, administrative divisions, and country information.'
;

create or replace TABLE DIM_BRANCH (
	BRANCH_KEY NUMBER(38,0),
	BRANCH_ID VARCHAR(16777216) NOT NULL,
	BRANCH_NAME VARCHAR(16777216),
	GEOGRAPHY_KEY NUMBER(38,0),
	BRANCH_TYPE VARCHAR(16777216),
	CREATED_TIMESTAMP TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    BRANCH_CITY VARCHAR(16777216),
	unique (BRANCH_ID),
	primary key (BRANCH_KEY),
	foreign key (GEOGRAPHY_KEY) references DIM_GEOGRAPHY(GEOGRAPHY_KEY)
)COMMENT='The table contains records of branch locations. Each record includes details about the branch''s geography, type, and creation timestamp.'
;

create or replace TABLE DIM_PRIVATE_BANKER (
	PRIVATE_BANKER_KEY NUMBER(38,0),
	BANKER_ID VARCHAR(16777216) NOT NULL,
	FIRST_NAME VARCHAR(16777216),
	LAST_NAME VARCHAR(16777216),
	FULL_NAME VARCHAR(16777216) NOT NULL,
	BRANCH_KEY NUMBER(38,0),
	TITLE VARCHAR(16777216),
	SPECIALIZATION VARCHAR(16777216),
	HIRE_DATE DATE,
	PHONE VARCHAR(16777216),
	EMAIL VARCHAR(16777216),
	LICENSE_SERIES VARCHAR(16777216),
	YEARS_EXPERIENCE NUMBER(38,0),
	EFFECTIVE_DATE DATE DEFAULT CURRENT_DATE(),
	EXPIRY_DATE DATE DEFAULT CAST('9999-12-31' AS DATE),
	IS_CURRENT BOOLEAN DEFAULT TRUE,
	CREATED_TIMESTAMP TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATED_TIMESTAMP TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	primary key (PRIVATE_BANKER_KEY),
	foreign key (BRANCH_KEY) references DIM_BRANCH(BRANCH_KEY)
)COMMENT='The table contains records of banking professionals, specifically private bankers. Each record represents a single banker and includes details about their employment status, contact information, and professional background.'
;

create or replace TABLE DIM_ACCOUNT (
	ACCOUNT_KEY NUMBER(38,0) NOT NULL autoincrement start 1 increment 1 noorder,
	CUSTOMER_ID VARCHAR(16777216) NOT NULL,
	ACCOUNT_TYPE VARCHAR(16777216),
	DATE_OF_ACCOUNT_OPENING DATE,
	ACCOUNT_OPENING_DATE_KEY NUMBER(38,0),
	EFFECTIVE_DATE DATE DEFAULT CURRENT_DATE(),
	EXPIRY_DATE DATE DEFAULT CAST('9999-12-31' AS DATE),
	IS_CURRENT BOOLEAN DEFAULT TRUE,
	CREATED_TIMESTAMP TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	OPENING_BALANCE NUMBER(15,2),
	CUSTOMER_KEY NUMBER(38,0),
	primary key (ACCOUNT_KEY)
)COMMENT='The table contains records of customer accounts. Each record represents a single account and includes details about the account type, customer information, and account status.'
;
create or replace TABLE DIM_CSR (
	CSR_KEY NUMBER(38,0),
	CSR_ID VARCHAR(16777216) NOT NULL,
	FIRST_NAME VARCHAR(16777216),
	LAST_NAME VARCHAR(16777216),
	FULL_NAME VARCHAR(16777216) NOT NULL,
	HIRE_DATE DATE,
	DEPARTMENT VARCHAR(16777216),
	SPECIALIZATION VARCHAR(16777216),
	EFFECTIVE_DATE DATE DEFAULT CURRENT_DATE(),
	EXPIRY_DATE DATE DEFAULT CAST('9999-12-31' AS DATE),
	IS_CURRENT BOOLEAN DEFAULT TRUE,
	CREATED_TIMESTAMP TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATED_TIMESTAMP TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	primary key (CSR_KEY)
)COMMENT='The table contains records of corporate staff members. Each record represents a single employee and includes details about their personal and professional information, including department and specialization.'
;
create or replace TABLE DIM_CUSTOMER (
	CUSTOMER_KEY NUMBER(38,0),
	CUSTOMER_ID VARCHAR(16777216) NOT NULL,
	FIRST_NAME VARCHAR(16777216),
	LAST_NAME VARCHAR(16777216),
	AGE NUMBER(38,0),
	GENDER VARCHAR(16777216),
	ADDRESS VARCHAR(16777216),
	CITY VARCHAR(16777216),
	CONTACT_NUMBER VARCHAR(16777216),
	EMAIL VARCHAR(16777216),
	EFFECTIVE_DATE DATE DEFAULT CURRENT_DATE(),
	EXPIRY_DATE DATE DEFAULT CAST('9999-12-31' AS DATE),
	IS_CURRENT BOOLEAN DEFAULT TRUE,
	CREATED_TIMESTAMP TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATED_TIMESTAMP TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	PRIVATE_BANKER_KEY NUMBER(38,0),
	primary key (CUSTOMER_KEY)
)COMMENT='The table contains customer information, including demographic and contact details. Each record represents a single customer and includes details about their personal and account status.'
;
create or replace TABLE DIM_DATE (
	DATE_KEY NUMBER(38,0),
	DATE_VALUE DATE,
	YEAR NUMBER(38,0),
	QUARTER NUMBER(38,0),
	MONTH NUMBER(38,0),
	MONTH_NAME VARCHAR(16777216),
	DAY NUMBER(38,0),
	DAY_OF_WEEK NUMBER(38,0),
	DAY_NAME VARCHAR(16777216),
	WEEK_OF_YEAR NUMBER(38,0),
	IS_WEEKEND BOOLEAN,
	IS_HOLIDAY BOOLEAN,
	FISCAL_YEAR NUMBER(38,0),
	FISCAL_QUARTER NUMBER(38,0)
)COMMENT='The table contains records of dates, categorized by their attributes such as year, quarter, month, and day. Each record represents a single date and includes details about its position within a calendar, including day of the week and fiscal year information.'
;
create or replace TABLE DIM_PRODUCT (
	PRODUCT_KEY NUMBER(38,0),
	PRODUCT_ID VARCHAR(16777216) NOT NULL,
	PRODUCT_TYPE VARCHAR(16777216),
	PRODUCT_SUBTYPE VARCHAR(16777216),
	PRODUCT_NAME VARCHAR(16777216),
	PRODUCT_CATEGORY VARCHAR(16777216),
	CREATED_TIMESTAMP TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	PRODUCT_DESCRIPTION VARCHAR(500),
	MIN_CREDIT_SCORE NUMBER(3,0),
	primary key (PRODUCT_KEY)
)COMMENT='The table contains records of products, including their characteristics and attributes. Each record represents a single product and includes details about its type, category, and description, as well as additional information such as credit score requirements.'
;

-- =====================================================
-- FACT TABLES
-- =====================================================
-- Fact tables containing transactional and snapshot data

create or replace TABLE FACT_CREDIT_CARD cluster by (snapshot_date_key)(
	CARD_SNAPSHOT_KEY NUMBER(38,0),
	CARD_ID VARCHAR(16777216) NOT NULL,
	CUSTOMER_KEY NUMBER(38,0) NOT NULL,
	PRODUCT_KEY NUMBER(38,0) NOT NULL,
	SNAPSHOT_DATE_KEY NUMBER(38,0) NOT NULL,
	PAYMENT_DUE_DATE_KEY NUMBER(38,0),
	LAST_PAYMENT_DATE_KEY NUMBER(38,0),
	CREDIT_LIMIT NUMBER(15,2),
	CREDIT_CARD_BALANCE NUMBER(15,2),
	MINIMUM_PAYMENT_DUE NUMBER(15,2),
	REWARDS_POINTS NUMBER(38,0),
	CREATED_TIMESTAMP TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	primary key (CARD_SNAPSHOT_KEY),
	foreign key (CUSTOMER_KEY) references DIM_CUSTOMER(CUSTOMER_KEY),
	foreign key (PRODUCT_KEY) references DIM_PRODUCT(PRODUCT_KEY)
)COMMENT='The table contains records of credit card accounts, including customer and product information, as well as financial details and payment history. Each record represents a snapshot of a customer''s credit card account at a specific point in time, capturing details about the account''s status and activity.'
;
create or replace TABLE FACT_CREDIT_SCORE (
	CREDIT_SCORE_KEY NUMBER(38,0),
	CUSTOMER_KEY NUMBER(38,0) NOT NULL,
	SCORE_DATE DATE DEFAULT CURRENT_DATE(),
	CREDIT_SCORE NUMBER(3,0),
	CREDIT_RISK_CATEGORY VARCHAR(50),
	SOURCE_SYSTEM VARCHAR(100),
	CREATED_TIMESTAMP TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	primary key (CREDIT_SCORE_KEY),
	foreign key (CUSTOMER_KEY) references DIM_CUSTOMER(CUSTOMER_KEY)
)COMMENT='The table contains credit scores for customers, including their current score and risk category. Each record represents a single customer and includes details about their credit score history and the source of the score.'
;
create or replace TABLE FACT_CSR_INTERACTION (
	CSR_INTERACTION_KEY NUMBER(38,0),
	CSR_KEY NUMBER(38,0) NOT NULL,
	CUSTOMER_KEY NUMBER(38,0) NOT NULL,
	INTERACTION_DATE_KEY NUMBER(38,0) NOT NULL,
	CALL_ID VARCHAR(16777216) NOT NULL,
	CALL_DATETIME TIMESTAMP_NTZ(9) NOT NULL,
	CALL_DESCRIPTION VARCHAR(16777216),
	CALL_SENTIMENT VARIANT,
	SENTIMENT_LABEL VARCHAR(16777216),
	CALL_COUNT NUMBER(1,0),
	POSITIVE_CALL_COUNT NUMBER(1,0),
	NEUTRAL_CALL_COUNT NUMBER(1,0),
	NEGATIVE_CALL_COUNT NUMBER(1,0),
	CREATED_TIMESTAMP TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	primary key (CSR_INTERACTION_KEY),
	foreign key (CSR_KEY) references DIM_CSR(CSR_KEY),
	foreign key (CUSTOMER_KEY) references DIM_CUSTOMER(CUSTOMER_KEY)
)COMMENT='The table contains records of customer interactions, specifically calls, with customer service representatives. Each record represents a single interaction and includes details about the customer, the interaction itself, and sentiment analysis results.'
;
create or replace TABLE FACT_FEEDBACK cluster by (feedback_date_key)(
	FEEDBACK_KEY NUMBER(38,0),
	FEEDBACK_ID VARCHAR(16777216) NOT NULL,
	CUSTOMER_KEY NUMBER(38,0) NOT NULL,
	FEEDBACK_DATE_KEY NUMBER(38,0) NOT NULL,
	RESOLUTION_DATE_KEY NUMBER(38,0),
	RESOLUTION_DAYS NUMBER(38,0),
	FEEDBACK_TYPE VARCHAR(16777216),
	RESOLUTION_STATUS VARCHAR(16777216),
	CREATED_TIMESTAMP TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	primary key (FEEDBACK_KEY),
	foreign key (CUSTOMER_KEY) references DIM_CUSTOMER(CUSTOMER_KEY)
)COMMENT='The table contains records of customer feedback, including ratings and comments. Each record represents a single feedback instance and includes details about the customer and the feedback status.'
;
create or replace TABLE FACT_LOAN (
	LOAN_KEY NUMBER(38,0),
	LOAN_ID VARCHAR(16777216) NOT NULL,
	CUSTOMER_KEY NUMBER(38,0) NOT NULL,
	PRODUCT_KEY NUMBER(38,0) NOT NULL,
	APPROVAL_DATE_KEY NUMBER(38,0),
	LOAN_AMOUNT NUMBER(15,2),
	INTEREST_RATE NUMBER(5,4),
	LOAN_TERM_MONTHS NUMBER(38,0),
	LOAN_STATUS VARCHAR(16777216),
	APPROVAL_REJECTION_DATE DATE,
	CREATED_TIMESTAMP TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	primary key (LOAN_KEY),
	foreign key (CUSTOMER_KEY) references DIM_CUSTOMER(CUSTOMER_KEY),
	foreign key (PRODUCT_KEY) references DIM_PRODUCT(PRODUCT_KEY)
)COMMENT='The table contains records of loan agreements. Each record represents a single loan and includes details about the customer, product, and loan terms.'
;
create or replace TABLE FACT_TRANSACTION (
	TRANSACTION_KEY NUMBER(38,0),
	TRANSACTION_ID VARCHAR(16777216),
	CUSTOMER_KEY NUMBER(38,0),
	ACCOUNT_KEY NUMBER(38,0),
	BRANCH_KEY NUMBER(38,0),
	TRANSACTION_DATE_KEY NUMBER(38,0),
	TRANSACTION_AMOUNT NUMBER(38,2),
	ACCOUNT_BALANCE_AFTER_TRANSACTION NUMBER(38,2),
	TRANSACTION_TYPE VARCHAR(16777216),
	ANOMALY_FLAG BOOLEAN,
	CREATED_TIMESTAMP TIMESTAMP_LTZ(9)
);


-- =====================================================
-- SECTION 4: DATA LOADING FROM EXTERNAL STAGE
-- =====================================================

-- =====================================================
-- LOAD STAGING TABLES FROM STAGE
-- =====================================================
-- Load raw data into staging tables for further processing
COPY INTO STG_CALL_CENTER_LOG (
    call_id,
    rep_id,
    rep_name,
    customer_id,
    customer_name,
    customer_email,
    call_datetime,
    call_description,
    call_transcript
)
FROM @BANKING_DEMO_7RIVERS_EXT_STAGE/data_files/call_center_logs.csv
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
);

COPY INTO STG_CHUNK_MARKETING_DOCUMENTS (
    RELATIVE_PATH,
    FILE_URL,
    CHUNK,
    LANGUAGE
)
FROM @BANKING_DEMO_7RIVERS_EXT_STAGE/data_files/stg_chunk_marketing_documents.csv
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
);

-- =====================================================
-- LOAD DIMENSION TABLES FROM STAGE
-- =====================================================
-- Load dimension tables with master data

-- Load customer account dimension
COPY INTO BANKING_DEMO_7RIVERS_DB.DW.DIM_ACCOUNT
FROM @BANKING_DEMO_7RIVERS_EXT_STAGE/data_files/dim_account_export.csv
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
);

-- Load branch location dimension
COPY INTO BANKING_DEMO_7RIVERS_DB.DW.DIM_BRANCH
FROM @BANKING_DEMO_7RIVERS_EXT_STAGE/data_files/dim_branch_export.csv
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
);

-- Load geographic location dimension
COPY INTO BANKING_DEMO_7RIVERS_DB.DW.DIM_GEOGRAPHY
FROM @BANKING_DEMO_7RIVERS_EXT_STAGE/data_files/dim_geography_export.csv
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
);

-- Load customer information dimension
COPY INTO BANKING_DEMO_7RIVERS_DB.DW.DIM_CUSTOMER
FROM @BANKING_DEMO_7RIVERS_EXT_STAGE/data_files/dim_customer_export.csv
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
);

-- Load private banker dimension
COPY INTO BANKING_DEMO_7RIVERS_DB.DW.DIM_PRIVATE_BANKER
FROM @BANKING_DEMO_7RIVERS_EXT_STAGE/data_files/dim_private_banker_export.csv
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
);

-- Load date dimension for time-based analysis
COPY INTO BANKING_DEMO_7RIVERS_DB.DW.DIM_DATE
FROM @BANKING_DEMO_7RIVERS_EXT_STAGE/data_files/dim_date_export.csv
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
);

-- Load banking product dimension (loans, credit cards, etc.)
COPY INTO BANKING_DEMO_7RIVERS_DB.DW.DIM_PRODUCT
FROM @BANKING_DEMO_7RIVERS_EXT_STAGE/data_files/dim_product_export.csv
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
);

-- Load customer service representative dimension
COPY INTO BANKING_DEMO_7RIVERS_DB.DW.DIM_CSR
FROM @BANKING_DEMO_7RIVERS_EXT_STAGE/data_files/dim_csr_export.csv
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
);

-- =====================================================
-- LOAD FACT TABLES FROM STAGE
-- =====================================================
-- Load fact tables containing transactional and measurement data

-- Load credit card snapshot fact table
COPY INTO BANKING_DEMO_7RIVERS_DB.DW.FACT_CREDIT_CARD
FROM @BANKING_DEMO_7RIVERS_EXT_STAGE/data_files/fact_credit_card_export.csv
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
);

-- Load loan fact table
COPY INTO BANKING_DEMO_7RIVERS_DB.DW.FACT_LOAN
FROM @BANKING_DEMO_7RIVERS_EXT_STAGE/data_files/fact_loan_export.csv
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
);

-- Load banking transaction fact table
COPY INTO BANKING_DEMO_7RIVERS_DB.DW.FACT_TRANSACTION
FROM @BANKING_DEMO_7RIVERS_EXT_STAGE/data_files/fact_transaction_export.csv
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
);

-- Load customer credit score fact table
COPY INTO BANKING_DEMO_7RIVERS_DB.DW.FACT_CREDIT_SCORE
FROM @BANKING_DEMO_7RIVERS_EXT_STAGE/data_files/fact_credit_score_export.csv
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
);

-- Load customer service interaction fact table with sentiment analysis
COPY INTO BANKING_DEMO_7RIVERS_DB.DW.FACT_CSR_INTERACTION
FROM @BANKING_DEMO_7RIVERS_EXT_STAGE/data_files/fact_csr_interaction_export.csv
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
);

-- =====================================================
-- SECTION 5: ANALYTICAL VIEWS
-- =====================================================
-- Business intelligence views for reporting and analysis

create or replace view VW_ACCOUNT_BALANCE(
	CUSTOMER_KEY,
	CUSTOMER_ID,
	FIRST_NAME,
	LAST_NAME,
	ACCOUNT_KEY,
	ACCOUNT_TYPE,
	ACCOUNT_CATEGORY,
	BALANCE_DATE_KEY,
	BALANCE_AMOUNT
) COMMENT='The table contains records of customer account balances. Each record represents a single customer''s account and includes details about the account type, category, and balance history.'
 as
with latest_transaction_per_account as (
select
ft.account_key,
ft.transaction_key,
ft.transaction_date_key,
ft.account_balance_after_transaction,
row_number() over (
partition by ft.account_key
order by ft.transaction_date_key desc, ft.transaction_key desc
) as rn
from FACT_TRANSACTION ft
),
latest_card_per_customer as (
select
fc.customer_key,
fc.card_snapshot_key,
fc.snapshot_date_key,
fc.credit_card_balance,
row_number() over (
partition by fc.customer_key
order by fc.snapshot_date_key desc, fc.card_snapshot_key desc
) as rn
from FACT_CREDIT_CARD fc
)
select
c.customer_key,
c.customer_id,
c.first_name,
c.last_name,
a.account_key,
a.account_type,
'BANK_ACCOUNT' as account_category,
lt.transaction_date_key as balance_date_key,
lt.account_balance_after_transaction as balance_amount
from DIM_ACCOUNT a
join latest_transaction_per_account lt
on a.account_key = lt.account_key
and lt.rn = 1
join DIM_CUSTOMER c
on a.customer_id = c.customer_id

union all

select
c.customer_key,
c.customer_id,
null as first_name,
null as last_name,
null as account_key,
'CREDIT_CARD' as account_type,
'CREDIT_CARD' as account_category,
lc.snapshot_date_key as balance_date_key,
lc.credit_card_balance as balance_amount
from latest_card_per_customer lc
join DIM_CUSTOMER c
on lc.customer_key = c.customer_key
where lc.rn = 1;


create or replace view VW_ANOMALY_MONITORING(
	TRANSACTION_DATE,
	TOTAL_TRANSACTIONS,
	ANOMALOUS_TRANSACTIONS,
	ANOMALY_PERCENTAGE,
	AVG_ANOMALY_AMOUNT
) COMMENT='The table contains records of transaction monitoring data. Each record represents a time period and includes metrics about the total number of transactions, anomalous transactions, and the percentage and average amount of anomalies.'
 as
SELECT 
  DATE_TRUNC('DAY', CREATED_TIMESTAMP) AS TRANSACTION_DATE,
  COUNT(1) AS TOTAL_TRANSACTIONS,
  SUM(IFF(ANOMALY_FLAG, 1, 0)) AS ANOMALOUS_TRANSACTIONS,
  ROUND(SUM(IFF(ANOMALY_FLAG, 1, 0)) * 100.0 / COUNT(1), 2) AS ANOMALY_PERCENTAGE,
  AVG(CASE WHEN ANOMALY_FLAG THEN TRANSACTION_AMOUNT END) AS AVG_ANOMALY_AMOUNT
FROM FACT_TRANSACTION
GROUP BY DATE_TRUNC('DAY', CREATED_TIMESTAMP)
ORDER BY TRANSACTION_DATE DESC;


create or replace view VW_BRANCH_PERFORMANCE(
	BRANCH_ID,
	BRANCH_NAME,
	CITY_NAME,
	STATE_NAME,
	REGION_NAME,
	BRANCH_TYPE,
	TOTAL_TRANSACTIONS,
	TOTAL_TRANSACTION_AMOUNT,
	AVG_TRANSACTION_AMOUNT,
	UNIQUE_CUSTOMERS
) COMMENT='The table contains records of branch performance metrics. Each record represents a single branch and includes details about its location, type, and customer activity.'
 as
SELECT 
    db.branch_id,
    db.branch_name,
    dg.city_name,
    dg.state_name,
    dg.region_name,
    db.branch_type,
    COUNT(ft.transaction_key) AS total_transactions,
    SUM(ft.transaction_amount) AS total_transaction_amount,
    AVG(ft.transaction_amount) AS avg_transaction_amount,
    COUNT(DISTINCT ft.customer_key) AS unique_customers
FROM FACT_TRANSACTION ft
JOIN DIM_BRANCH db ON ft.branch_key = db.branch_key
LEFT JOIN DIM_GEOGRAPHY dg ON db.geography_key = dg.geography_key
GROUP BY db.branch_id, db.branch_name, dg.city_name, dg.state_name, dg.region_name, db.branch_type;

create or replace view VW_CREDIT_CARD_METRICS(
	CARD_ID,
	CUSTOMER_KEY,
	SNAPSHOT_DATE_KEY,
	CREDIT_LIMIT,
	CREDIT_CARD_BALANCE,
	CREDIT_UTILIZATION_RATIO,
	MINIMUM_PAYMENT_DUE,
	REWARDS_POINTS
) COMMENT='The table contains records of credit card account metrics, specifically customer credit card usage and financial data. Each record represents a snapshot of a customer''s credit card account and includes details about the account balance, credit limit, and payment information.'
 as
SELECT
    card_id,
    customer_key,
    snapshot_date_key,
    credit_limit,
    credit_card_balance,
    CASE WHEN credit_limit > 0 THEN credit_card_balance / credit_limit ELSE NULL END AS credit_utilization_ratio,
    minimum_payment_due,
    rewards_points
FROM FACT_CREDIT_CARD;

create or replace view VW_CUSTOMER_TRANSACTION_SUMMARY(
	CUSTOMER_ID,
	FULL_NAME,
	CITY,
	TOTAL_TRANSACTIONS,
	TOTAL_TRANSACTION_AMOUNT,
	AVG_TRANSACTION_AMOUNT,
	LAST_TRANSACTION_DATE,
	TOTAL_DEPOSITS,
	TOTAL_WITHDRAWALS
) COMMENT='The table contains records of customer transaction summaries, specifically financial activity. Each record represents a single customer and includes details about their transaction history, including total transactions, amounts, and deposit/withdrawal activity.'
 as
select
    dc.CUSTOMER_ID,
    concat(coalesce(dc.FIRST_NAME,''), ' ', coalesce(dc.LAST_NAME,'')) as FULL_NAME,
    dc.CITY,
    count(ft.TRANSACTION_KEY)                                                      as TOTAL_TRANSACTIONS,
    sum(coalesce(ft.TRANSACTION_AMOUNT,0))                                         as TOTAL_TRANSACTION_AMOUNT,
    avg(coalesce(ft.TRANSACTION_AMOUNT,0))                                         as AVG_TRANSACTION_AMOUNT,
    max(dd.DATE_VALUE)                                                             as LAST_TRANSACTION_DATE,
    sum( case when upper(coalesce(ft.TRANSACTION_TYPE,'')) = 'DEPOSIT'
              then coalesce(ft.TRANSACTION_AMOUNT,0) else 0 end )                  as TOTAL_DEPOSITS,
    sum( case when upper(coalesce(ft.TRANSACTION_TYPE,'')) = 'WITHDRAWAL'
              then coalesce(ft.TRANSACTION_AMOUNT,0) else 0 end )                  as TOTAL_WITHDRAWALS
from FACT_TRANSACTION  ft
join DIM_CUSTOMER      dc
  on ft.CUSTOMER_KEY     = dc.CUSTOMER_KEY
join DIM_DATE          dd
  on ft.TRANSACTION_DATE_KEY = dd.DATE_KEY
where coalesce(dc.IS_CURRENT, true)
group by
    dc.CUSTOMER_ID, dc.FIRST_NAME, dc.LAST_NAME, dc.CITY;

create or replace view VW_MONTHLY_TRANSACTION_TRENDS(
	YEAR,
	MONTH,
	MONTH_NAME,
	TRANSACTION_COUNT,
	TOTAL_AMOUNT,
	AVG_AMOUNT,
	UNIQUE_CUSTOMERS
) COMMENT='The table contains records of monthly transaction trends. Each record represents a single month and includes metrics about the number of transactions, total amount, average amount, and unique customers.'
 as
SELECT 
    dd.year,
    dd.month,
    dd.month_name,
    COUNT(ft.transaction_key) AS transaction_count,
    SUM(ft.transaction_amount) AS total_amount,
    AVG(ft.transaction_amount) AS avg_amount,
    COUNT(DISTINCT ft.customer_key) AS unique_customers
FROM FACT_TRANSACTION ft
JOIN DIM_DATE dd ON ft.transaction_date_key = dd.date_key
GROUP BY dd.year, dd.month, dd.month_name
ORDER BY dd.year, dd.month;


create or replace view VW_REGIONAL_ANALYSIS(
	REGION_NAME,
	STATE_NAME,
	BRANCH_COUNT,
	TOTAL_TRANSACTIONS,
	TOTAL_TRANSACTION_AMOUNT,
	AVG_TRANSACTION_AMOUNT,
	UNIQUE_CUSTOMERS
) COMMENT='The table contains regional analysis data, specifically metrics related to branches and transactions. Each record represents a geographic region and includes details about branch counts, transaction volumes, and customer activity.'
 as
SELECT 
    dg.region_name,
    dg.state_name,
    COUNT(DISTINCT db.branch_key) AS branch_count,
    COUNT(ft.transaction_key) AS total_transactions,
    SUM(ft.transaction_amount) AS total_transaction_amount,
    AVG(ft.transaction_amount) AS avg_transaction_amount,
    COUNT(DISTINCT ft.customer_key) AS unique_customers
FROM FACT_TRANSACTION ft
JOIN DIM_BRANCH db ON ft.branch_key = db.branch_key
LEFT JOIN DIM_GEOGRAPHY dg ON db.geography_key = dg.geography_key
GROUP BY dg.region_name, dg.state_name
ORDER BY dg.region_name, dg.state_name;


-- =====================================================
-- SECTION 6: CORTEX AI SEARCH SERVICES
-- =====================================================
-- Snowflake Cortex Search services for semantic search capabilities

-- Call center search service for finding relevant customer interactions
create or replace CORTEX SEARCH SERVICE BANKING_DEMO_7RIVERS_CALL_CENTER_SEARCH
ON CALL_TRANSCRIPT
ATTRIBUTES CALL_ID, REP_ID, REP_NAME, CUSTOMER_ID, CUSTOMER_NAME, CALL_DATETIME, CALL_DESCRIPTION
WAREHOUSE = BANKING_DEMO_7RIVERS_WH
TARGET_LAG = '1 HOUR'
AS (
    SELECT
        CALL_TRANSCRIPT,
        CALL_ID,
        REP_ID,
        REP_NAME,
        CUSTOMER_ID,
        CUSTOMER_NAME,
        CALL_DATETIME,
        CALL_DESCRIPTION
    FROM STG_CALL_CENTER_LOG
    WHERE CALL_TRANSCRIPT IS NOT NULL
);

-- Marketing documents search service for product information retrieval
create or replace CORTEX SEARCH SERVICE BANKING_DEMO_7RIVERS_MARKETING_SEARCH
ON CHUNK
ATTRIBUTES LANGUAGE, RELATIVE_PATH
WAREHOUSE = BANKING_DEMO_7RIVERS_WH
TARGET_LAG = '1 HOUR'
AS (
    SELECT
      CHUNK,
      RELATIVE_PATH,
      FILE_URL,
      LANGUAGE
    FROM STG_CHUNK_MARKETING_DOCUMENTS
);

-- =====================================================
-- SECTION 7: SEMANTIC VIEW FOR CORTEX ANALYST
-- =====================================================
-- Semantic view enables natural language querying via Snowflake Cortex Analyst
-- Defines table relationships, synonyms, and business context for AI-powered analytics

create or replace semantic view BANKING_DEMO_7RIVERS_DB.DW.BANKING_DEMO_7RIVERS_SV
	tables (
		DIM_ACCOUNT primary key (ACCOUNT_KEY) with synonyms=('account_details','account_info','account_records','account_table','customer_accounts') comment='The table contains records of customer accounts. Each record represents a single account and includes details about the account type, customer information, and account status.',
		DIM_BRANCH primary key (BRANCH_KEY) with synonyms=('branch_details','branch_info','branch_locations','geography_branches') comment='The table contains records of branch locations, including details about the branch''s geography, type, and creation timestamp.',
		DIM_CSR primary key (CSR_KEY) comment='The table contains records of corporate staff members. Each record represents a single employee and includes details about their personal and professional information, including department and specialization.',
		DIM_CUSTOMER primary key (CUSTOMER_KEY) with synonyms=('account_holder','client','customer','individual','person') comment='The table contains customer information, including demographic and contact details. Each record represents a single customer and includes details about their personal and account status.',
		DIM_DATE primary key (DATE_KEY) with synonyms=('CALENDAR_DATA','CALENDAR_DIM','CALENDAR_TABLE','DATE_DIMENSION','DATE_INFO','DATE_LOOKUP','DATE_MASTER','DATE_REFERENCE','TIME_DIMENSION','TIME_INFO') comment='The DIM_DATE table is a date dimension table that stores a record for each date, providing a centralized repository of date-related attributes and calculations, enabling efficient analysis and reporting of time-based data across various business dimensions.',
		DIM_GEOGRAPHY primary key (GEOGRAPHY_KEY) comment='The table contains records of geographic locations, specifically cities and regions. Each record includes details about the location''s name, administrative divisions, and country information.',
		DIM_PRIVATE_BANKER primary key (PRIVATE_BANKER_KEY) comment='The table contains records of banking professionals, specifically private bankers. Each record represents a single banker and includes details about their employment status, contact information, and professional background.',
		DIM_PRODUCT primary key (PRODUCT_KEY) with synonyms=('product_catalog','product_inventory','product_list','product_master','product_reference','products') comment='The table contains records of products, including their characteristics and attributes. Each record represents a single product and includes details about its type, category, and description, as well as additional information such as credit score requirements.',
		FACT_CREDIT_CARD primary key (CARD_SNAPSHOT_KEY) with synonyms=('credit_card_account','credit_card_details','credit_card_info','credit_card_record','credit_card_snapshot','credit_card_transaction_history','customer_credit_card') comment='The table contains records of credit card accounts, including customer and product information, as well as financial details and payment history. Each record represents a snapshot of a customer''s credit card account at a specific point in time, capturing details about the account''s status and activity.',
		FACT_CREDIT_SCORE primary key (CREDIT_SCORE_KEY) comment='This table stores historical credit score information for customers, including the date the score was recorded, the actual credit score, and the associated credit risk category, as well as metadata about the source system and timestamp of data creation.',
		FACT_CSR_INTERACTION primary key (CSR_INTERACTION_KEY) comment='The table contains records of customer interactions, specifically calls, with customer service representatives. Each record represents a single interaction and includes details about the customer, the interaction itself, and sentiment analysis results.',
		FACT_LOAN primary key (LOAN_KEY) with synonyms=('loan_agreements','loan_data','loan_details','loan_info','loan_master','loan_records','loan_register','loan_table') comment='The table contains records of loan agreements. Each record represents a single loan and includes details about the customer, product, and loan terms.',
		FACT_TRANSACTION primary key (TRANSACTION_KEY) with synonyms=('financial_records','financial_transactions','transaction_log','transaction_records','transactional_data','transactional_history') comment='This table stores historical records of financial transactions, capturing key details such as transaction amount, account balance, and transaction type, as well as flags to indicate potential anomalies or adjustments, providing a comprehensive audit trail for financial analysis and compliance purposes.',
		VW_ACCOUNT_BALANCE with synonyms=('account_balances','account_history','account_summary','balance_sheet','customer_account_balances','customer_transactions') comment='The table contains records of customer account balances, including both bank accounts and credit cards, with details about the account type, category, and balance history, providing a comprehensive view of each customer''s financial situation.',
		VW_CREDIT_CARD_METRICS with synonyms=('credit_card_account_details','credit_card_account_metrics','credit_card_data','credit_card_financials','credit_card_usage','customer_credit_card_info') comment='The table contains records of credit card account metrics, specifically customer credit card usage and financial data. Each record represents a snapshot of a customer''s credit card account and includes details about the account balance, credit limit, and payment information.',
		VW_CUSTOMER_TRANSACTION_SUMMARY with synonyms=('customer_account_summary','customer_activity_summary','customer_financial_summary','customer_ledger','customer_transaction_summary','financial_activity_report','transaction_history') comment='The table contains records of customer transaction summaries, specifically financial activity. Each record represents a single customer and includes details about their transaction history, including total transactions, amounts, and deposit/withdrawal activity.'
	)
	relationships (
		ACCOUNT_TO_CUSTOMER as DIM_ACCOUNT(CUSTOMER_KEY) references DIM_CUSTOMER(CUSTOMER_KEY),
		BRANCH_TO_GEOGRAPHY as DIM_BRANCH(GEOGRAPHY_KEY) references DIM_GEOGRAPHY(GEOGRAPHY_KEY),
		CUSTOMER_TO_PRIVATE_BANKER as DIM_CUSTOMER(PRIVATE_BANKER_KEY) references DIM_PRIVATE_BANKER(PRIVATE_BANKER_KEY),
		CREDIT_CARD_TO_CUSTOMER as FACT_CREDIT_CARD(CUSTOMER_KEY) references DIM_CUSTOMER(CUSTOMER_KEY),
		CREDIT_CARD_SNAPSHOT_TO_DATE as FACT_CREDIT_CARD(SNAPSHOT_DATE_KEY) references DIM_DATE(DATE_KEY),
		CREDIT_CART_TO_PRODUCT as FACT_CREDIT_CARD(PRODUCT_KEY) references DIM_PRODUCT(PRODUCT_KEY),
		CREDIT_SCORE_TO_CUSTOMER as FACT_CREDIT_SCORE(CUSTOMER_KEY) references DIM_CUSTOMER(CUSTOMER_KEY),
		CSR_INTERACTION_TO_CSR as FACT_CSR_INTERACTION(CSR_KEY) references DIM_CSR(CSR_KEY),
		CSR_INTERACTION_TO_CUSTOMER as FACT_CSR_INTERACTION(CUSTOMER_KEY) references DIM_CUSTOMER(CUSTOMER_KEY),
		CSR_INTERACTION_TO_DATE as FACT_CSR_INTERACTION(INTERACTION_DATE_KEY) references DIM_DATE(DATE_KEY),
		LOAN_TO_CUSTOMER as FACT_LOAN(CUSTOMER_KEY) references DIM_CUSTOMER(CUSTOMER_KEY),
		LOAN_APPROVAL_TO_DATE as FACT_LOAN(APPROVAL_DATE_KEY) references DIM_DATE(DATE_KEY),
		LOAN_TO_PRODUCT as FACT_LOAN(PRODUCT_KEY) references DIM_PRODUCT(PRODUCT_KEY),
		TRANSACTION_TO_ACCOUNT as FACT_TRANSACTION(ACCOUNT_KEY) references DIM_ACCOUNT(ACCOUNT_KEY),
		BRANCH_TO_TRANSACTION as FACT_TRANSACTION(BRANCH_KEY) references DIM_BRANCH(BRANCH_KEY),
		TRANSACTION_TO_CUSTOMER as FACT_TRANSACTION(CUSTOMER_KEY) references DIM_CUSTOMER(CUSTOMER_KEY),
		TRANSACTION_DATE_KEY_JOIN as FACT_TRANSACTION(TRANSACTION_DATE_KEY) references DIM_DATE(DATE_KEY),
		TRANSACTION_TO_DATE as FACT_TRANSACTION(TRANSACTION_DATE_KEY) references DIM_DATE(DATE_KEY),
		ACCOUNT_BALANCE_TO_ACCOUNT as VW_ACCOUNT_BALANCE(ACCOUNT_KEY) references DIM_ACCOUNT(ACCOUNT_KEY),
		CC_TO_CUSTID as VW_CREDIT_CARD_METRICS(CUSTOMER_KEY) references DIM_CUSTOMER(CUSTOMER_KEY)
	)
	facts (
		DIM_ACCOUNT.ACCOUNT_KEY as ACCOUNT_KEY with synonyms=('account_id','account_identifier','account_number','account_reference','unique_account_code') comment='Unique identifier for an account.',
		DIM_BRANCH.BRANCH_KEY as BRANCH_KEY comment='Unique identifier for a specific branch location within the organization.',
		DIM_CSR.CSR_KEY as CSR_KEY comment='Unique identifier for a Customer Service Representative.',
		DIM_CUSTOMER.AGE as AGE with synonyms=('age_in_years','birth_age','customer_age','years_of_age','years_old','years_since_birth') comment='The age of the customer in years.',
		DIM_CUSTOMER.CUSTOMER_KEY as CUSTOMER_KEY comment='Unique identifier for a customer in the database, used to link customer data across different tables and facilitate analysis and reporting.',
		DIM_GEOGRAPHY.GEOGRAPHY_KEY as GEOGRAPHY_KEY comment='Unique identifier for a geographic location, such as a country, region, or city, used to link to other tables containing geographic data.',
		DIM_PRIVATE_BANKER.BRANCH_KEY as BRANCH_KEY comment='Unique identifier for a private banker''s branch location.',
		DIM_PRIVATE_BANKER.PRIVATE_BANKER_KEY as PRIVATE_BANKER_KEY comment='Unique identifier for a private banker.',
		DIM_PRIVATE_BANKER.YEARS_EXPERIENCE as YEARS_EXPERIENCE comment='The number of years of work experience of a private banker.',
		FACT_CREDIT_CARD.CARD_SNAPSHOT_KEY as CARD_SNAPSHOT_KEY with synonyms=('card_id','card_record_id','credit_card_key','credit_card_snapshot_id','snapshot_id') comment='Unique identifier for a credit card balance snapshot record.',
		FACT_CREDIT_CARD.CREDIT_CARD_BALANCE as CREDIT_CARD_BALANCE with synonyms=('account_balance','amount_owed','balance_due','card_balance','current_balance','outstanding_balance') comment='The outstanding balance on the customer''s credit card account.',
		FACT_CREDIT_CARD.MINIMUM_PAYMENT_DUE as MINIMUM_PAYMENT_DUE with synonyms=('minimum_amount_due','minimum_due_payment','minimum_payment_amount','minimum_payment_required','payment_minimum') comment='The minimum amount that must be paid by the credit card holder to avoid late fees and penalties.',
		FACT_CREDIT_CARD.REWARDS_POINTS as REWARDS_POINTS with synonyms=('bonus_points','incentive_points','loyalty_balance','loyalty_points','points_earned','reward_balance') comment='The total number of rewards points earned by the customer through credit card transactions.',
		FACT_CREDIT_SCORE.CREDIT_SCORE as CREDIT_SCORE comment='The credit score of a customer, which is a three-digit number that represents their creditworthiness and is used to determine their eligibility for credit and the interest rates they qualify for.',
		FACT_CREDIT_SCORE.CREDIT_SCORE_KEY as CREDIT_SCORE_KEY comment='A unique identifier for a customer''s credit score, used to link to the DIM_CREDIT_SCORE dimension table for detailed credit score information.',
		FACT_CREDIT_SCORE.CUSTOMER_KEY as CUSTOMER_KEY comment='Unique identifier for a customer in the credit scoring system.',
		FACT_CSR_INTERACTION.CALL_COUNT as CALL_COUNT comment='The total number of calls made by a customer service representative during an interaction with a customer.',
		FACT_CSR_INTERACTION.CSR_INTERACTION_KEY as CSR_INTERACTION_KEY comment='Unique identifier for a customer service representative interaction.',
		FACT_CSR_INTERACTION.INTERACTION_DATE_KEY as INTERACTION_DATE_KEY comment='Date on which the customer interaction occurred, in the format YYYYMMDD.',
		FACT_CSR_INTERACTION.NEGATIVE_CALL_COUNT as NEGATIVE_CALL_COUNT comment='The total number of calls made to the customer service representative that had a negative outcome or resulted in an unsatisfied customer.',
		FACT_CSR_INTERACTION.NEUTRAL_CALL_COUNT as NEUTRAL_CALL_COUNT comment='The total number of neutral calls made by a customer service representative.',
		FACT_CSR_INTERACTION.POSITIVE_CALL_COUNT as POSITIVE_CALL_COUNT comment='The number of times a customer has made a positive call to the customer service representative.',
		FACT_LOAN.INTEREST_RATE as INTEREST_RATE with synonyms=('annual_percentage_rate','apr','interest_percentage','loan_rate','rate_of_interest') comment='The interest rate charged on a loan, expressed as a percentage.',
		FACT_LOAN.LOAN_AMOUNT as LOAN_AMOUNT with synonyms=('borrowed_amount','borrowed_sum','loan_principal','loan_size','loan_size_value','loan_value','principal_amount') comment='The total amount borrowed by a customer for a specific loan.',
		FACT_LOAN.LOAN_KEY as LOAN_KEY comment='Unique identifier for a loan, used to link to other tables that contain additional loan information.',
		FACT_LOAN.LOAN_TERM_MONTHS as LOAN_TERM_MONTHS with synonyms=('loan_duration','loan_length','loan_life','loan_maturity','loan_period','loan_tenure','repayment_period','term_length') comment='The number of months over which a loan is scheduled to be repaid.',
		FACT_TRANSACTION.ACCOUNT_BALANCE_AFTER_TRANSACTION as ACCOUNT_BALANCE_AFTER_TRANSACTION with synonyms=('balance_after','current_balance','new_balance','post_transaction_balance','remaining_balance','updated_balance') comment='The account balance immediately after the transaction was processed.',
		FACT_TRANSACTION.TRANSACTION_AMOUNT as TRANSACTION_AMOUNT with synonyms=('amount','monetary_value','payment_amount','transaction_sum','transaction_value','transfer_amount') comment='The monetary amount of the transaction.',
		FACT_TRANSACTION.TRANSACTION_KEY as TRANSACTION_KEY comment='Unique identifier for each transaction record.',
		VW_ACCOUNT_BALANCE.ACCOUNT_KEY as ACCOUNT_KEY comment='Unique identifier for an account in the financial system, used to track and manage account balances and transactions.',
		VW_ACCOUNT_BALANCE.BALANCE_AMOUNT as BALANCE_AMOUNT comment='The current balance amount of the account, representing the total value of funds available in the account.',
		VW_ACCOUNT_BALANCE.BALANCE_DATE_KEY as BALANCE_DATE_KEY comment='Date key representing the date for which the account balance is calculated, in the format YYYYMMDD.',
		VW_ACCOUNT_BALANCE.CUSTOMER_KEY as CUSTOMER_KEY comment='Unique identifier for a customer in the system, used to link to customer information across different tables and systems.',
		VW_CREDIT_CARD_METRICS.CREDIT_CARD_BALANCE as CREDIT_CARD_BALANCE with synonyms=('account_balance','amount_owed','balance_due','card_balance','current_balance','outstanding_balance') comment='The outstanding balance on a customer''s credit card account.',
		VW_CREDIT_CARD_METRICS.CREDIT_LIMIT as CREDIT_LIMIT with synonyms=('available_credit','credit_allowance','credit_cap','credit_ceiling','credit_maximum','max_credit') comment='The maximum amount of credit available to a customer for a specific credit card account.',
		VW_CREDIT_CARD_METRICS.CREDIT_UTILIZATION_RATIO as CREDIT_UTILIZATION_RATIO with synonyms=('credit_balance_to_limit_ratio','credit_efficiency_ratio','credit_to_limit_ratio','credit_usage_rate','credit_utilization_percentage','utilization_rate') comment='The percentage of available credit being utilized by a customer, calculated by dividing the total outstanding balance by the total credit limit.',
		VW_CREDIT_CARD_METRICS.MINIMUM_PAYMENT_DUE as MINIMUM_PAYMENT_DUE with synonyms=('minimum_amount_due','minimum_due_payment','minimum_payment_amount','minimum_payment_required','payment_due_date','payment_minimum') comment='The minimum amount that must be paid by the credit card holder to avoid late fees and penalties for a specific billing cycle.',
		VW_CREDIT_CARD_METRICS.REWARDS_POINTS as REWARDS_POINTS with synonyms=('bonus_points','incentive_points','loyalty_balance','loyalty_points','points_earned','reward_balance') comment='The total number of rewards points earned by a customer through their credit card transactions.',
		VW_CUSTOMER_TRANSACTION_SUMMARY.AVG_TRANSACTION_AMOUNT as AVG_TRANSACTION_AMOUNT with synonyms=('average_purchase_value','average_spend','average_transaction_value','mean_transaction_amount','transaction_average') comment='The average amount spent by a customer in a single transaction.',
		VW_CUSTOMER_TRANSACTION_SUMMARY.TOTAL_DEPOSITS as TOTAL_DEPOSITS with synonyms=('deposited_funds_total','total_deposit_amount','total_deposited_amount','total_deposited_funds','total_funds_deposited','total_incoming_funds') comment='The total amount of money deposited by a customer into their account.',
		VW_CUSTOMER_TRANSACTION_SUMMARY.TOTAL_TRANSACTIONS as TOTAL_TRANSACTIONS with synonyms=('activity_count','total_activity','total_events','transaction_count','transaction_frequency','transaction_volume') comment='The total number of transactions made by a customer.',
		VW_CUSTOMER_TRANSACTION_SUMMARY.TOTAL_TRANSACTION_AMOUNT as TOTAL_TRANSACTION_AMOUNT with synonyms=('aggregate_transaction_amount','cumulative_transaction_value','overall_transaction_value','total_amount_transacted','total_expenditure','total_spent') comment='The total amount spent by a customer across all transactions.',
		VW_CUSTOMER_TRANSACTION_SUMMARY.TOTAL_WITHDRAWALS as TOTAL_WITHDRAWALS with synonyms=('total_amount_withdrawn','total_cash_out','total_cash_taken_out','total_funds_pulled_out','total_funds_removed','total_withdrawn_amount') comment='The total amount of money withdrawn by a customer from their account.'
	)
	dimensions (
		DIM_ACCOUNT.ACCOUNT_TYPE as ACCOUNT_TYPE with synonyms=('account_category','account_classification','account_description','account_kind') comment='The type of account held by a customer, either a current account for everyday transactions or a savings account for storing funds.',
		DIM_ACCOUNT.CUSTOMER_ID as CUSTOMER_ID with synonyms=('account_holder','account_owner','client_id','client_key','customer_key','customer_reference') comment='Business identifier for a customer, used for external reference and reporting.',
		DIM_ACCOUNT.CUSTOMER_KEY as CUSTOMER_KEY comment='Foreign key to customer dimension',
		DIM_ACCOUNT.DATE_OF_ACCOUNT_OPENING as DATE_OF_ACCOUNT_OPENING with synonyms=('account_creation_date','account_initiation_date','account_opening_date','account_start_date','date_account_opened') comment='The date when the account was first opened. Dates are formatted YYYY-MM-DD',
		DIM_ACCOUNT.EFFECTIVE_DATE as EFFECTIVE_DATE with synonyms=('activation_date','commencement_date','effective_from_date','enforcement_date','implementation_date','start_date') comment='The date when the account became active or a change to the account took effect.',
		DIM_ACCOUNT.EXPIRY_DATE as EXPIRY_DATE with synonyms=('date_of_expiry','end_date','expiration_date','expiry_timestamp','termination_date','validity_end_date') comment='The date by which an account is set to expire, with a default value of December 31, 9999 indicating no expiration date has been set.',
		DIM_ACCOUNT.IS_CURRENT as IS_CURRENT with synonyms=('active','active_status','current_state','current_status','is_active','status','valid') comment='Indicates whether the account is currently active or not.',
		DIM_BRANCH.BRANCH_CITY as BRANCH_CITY with synonyms=('branch_location','branch_town','city','city_name','geographic_location','location','municipal_area','urban_area') comment='The city where the branch is located.',
		DIM_BRANCH.BRANCH_ID as BRANCH_ID with synonyms=('branch_code','facility_id','location_id','outlet_number','site_identifier','store_number') comment='Unique identifier for a branch location within the organization.',
		DIM_BRANCH.BRANCH_NAME as BRANCH_NAME with synonyms=('branch_title','facility_name','location_name','office_name','site_name') comment='The name of the branch location, used to identify and distinguish between different physical locations of the organization.',
		DIM_BRANCH.BRANCH_TYPE as BRANCH_TYPE with synonyms=('branch_category','branch_classification','facility_type','location_type','office_classification','site_type') comment='The type of banking services offered by a branch, categorized as Full Service, Limited Service, or ATM Only, indicating the range and complexity of financial services provided to customers.',
		DIM_BRANCH.GEOGRAPHY_KEY as GEOGRAPHY_KEY with synonyms=('geo_key','geographic_key','location_key') comment='Foreign key for geographic location, used to link to other tables that contain geographic information.',
		DIM_CSR.CSR_ID as CSR_ID comment='Unique identifier for a Customer Service Representative.',
		DIM_CSR.DEPARTMENT as DEPARTMENT comment='The department within the organization that a customer service representative belongs to, indicating the level of service they provide, with ''Premium'' representing a higher level of service and ''General'' representing a standard level of service.',
		DIM_CSR.EFFECTIVE_DATE as EFFECTIVE_DATE comment='The date when a customer service representative (CSR) becomes effective or is assigned to a particular role or responsibility.',
		DIM_CSR.EXPIRY_DATE as EXPIRY_DATE comment='The date by which a customer service representative''s (CSR) access or certification is set to expire.',
		DIM_CSR.FIRST_NAME as FIRST_NAME comment='The first name of the customer service representative.',
		DIM_CSR.FULL_NAME as FULL_NAME comment='The full name of the customer service representative.',
		DIM_CSR.HIRE_DATE as HIRE_DATE comment='Date on which the customer service representative was hired.',
		DIM_CSR.IS_CURRENT as IS_CURRENT comment='Indicates whether the customer service representative is currently active or not.',
		DIM_CSR.LAST_NAME as LAST_NAME comment='The last name of the customer service representative.',
		DIM_CSR.SPECIALIZATION as SPECIALIZATION comment='The type of specialized service or expertise provided by a customer service representative, such as resolving disputes, providing technical assistance, or a focus on fraud and security issues.',
		DIM_CUSTOMER.ADDRESS as ADDRESS with synonyms=('customer_location','home_address','mailing_address','physical_address','residence','street_address') comment='The physical location of the customer.',
		DIM_CUSTOMER.CITY as CITY with synonyms=('geographical_location','location','metropolis','municipality','municipality_name','place','town','urban_area','urban_center') comment='The city where the customer is located.',
		DIM_CUSTOMER.CUSTOMER_ID as CUSTOMER_ID with synonyms=('client_id','client_reference','customer_code','customer_reference') comment='Unique identifier for each customer in the database, used to distinguish and track individual customer records.',
		DIM_CUSTOMER.FIRST_NAME as FIRST_NAME with synonyms=('christian_name','first_name','forename','given_name','personal_name') comment='The first name of the customer.',
		DIM_CUSTOMER.GENDER as GENDER with synonyms=('biological_sex','demographic','gender_identity','male_female','sex') comment='The gender of the customer, indicating whether the customer is male, female, or identifies as other.',
		DIM_CUSTOMER.EFFECTIVE_DATE as EFFECTIVE_DATE with synonyms=('activation_date','begin_date','commencement_date','initiation_date','start_date') comment='The date when the customer''s information became effective or was last updated.',
		DIM_CUSTOMER.EXPIRY_DATE as EXPIRY_DATE with synonyms=('date_of_expiry','end_date','end_of_validity_date','expiration_date','termination_date','validity_end_date') comment='The date by which the customer''s information is no longer valid or is scheduled to be removed from the system.',
		DIM_CUSTOMER.IS_CURRENT as IS_CURRENT with synonyms=('active_flag','active_indicator','current_record','current_status','is_active','is_valid','status_current') comment='Indicates whether the customer is currently active or not.',
		DIM_CUSTOMER.LAST_NAME as LAST_NAME with synonyms=('family_name','family_surname','full_last_name','last_name_field','patronymic','surname') comment='The customer''s last name.',
		DIM_CUSTOMER.PRIVATE_BANKER_KEY as PRIVATE_BANKER_KEY with synonyms=('banker_key') comment='Foreign key to private banker dimension',
		DIM_DATE.DATE_VALUE as DATE_VALUE with synonyms=('calendar_date','date','date_recorded') comment='Date of the calendar, used to track and analyze data over time.',
		DIM_DATE.DAY as DAY with synonyms=('calendar_day','daily_value','day_number','day_of_month','day_of_year') comment='The day of the month, ranging from 1 to 31, representing the specific day within a month.',
		DIM_DATE.DAY_NAME as DAY_NAME with synonyms=('day_name_full','day_of_week_name','full_day_name','weekday_full_name','weekday_name') comment='The full name of the day of the week.',
		DIM_DATE.DAY_OF_WEEK as DAY_OF_WEEK with synonyms=('day_index','day_of_week_id','day_of_week_number','weekday','weekday_number') comment='The day of the week on which a date falls, where 1 = Sunday, 2 = Monday, 3 = Tuesday, 4 = Wednesday, 5 = Thursday, 6 = Friday, and 7 = Saturday.',
		DIM_DATE.FISCAL_QUARTER as FISCAL_QUARTER with synonyms=('financial_quarter','quarter_of_fiscal_year') comment='The quarter of the fiscal year to which the date belongs, with 1 representing the first quarter, 2 representing the second quarter, 3 representing the third quarter, and 4 representing the fourth quarter.',
		DIM_DATE.FISCAL_YEAR as FISCAL_YEAR with synonyms=('accounting_year','budget_year','financial_year','tax_year') comment='The fiscal year in which a date falls, typically used for financial reporting and budgeting purposes.',
		DIM_DATE.IS_HOLIDAY as IS_HOLIDAY with synonyms=('is_bank_holiday','is_day_off','is_federal_holiday','is_public_holiday','is_special_day') comment='Indicates whether the date is a holiday or not.',
		DIM_DATE.IS_WEEKEND as IS_WEEKEND with synonyms=('is_saturday_or_sunday','non_business_day','non_weekday','saturday_or_sunday','weekend_day') comment='Indicates whether a date falls on a weekend (Saturday or Sunday) or not.',
		DIM_DATE.MONTH as MONTH with synonyms=('calendar_month','month_code','month_number','month_of_year','month_value') comment='The month of the year, represented as a numerical value ranging from 1 (January) to 12 (December), indicating the month to which a specific date belongs.',
		DIM_DATE.MONTH_NAME as MONTH_NAME with synonyms=('full_month_name','month_description','month_full_name','month_label','month_title') comment='The full name of the month, such as January, February, or March, represented in abbreviated form.',
		DIM_DATE.QUARTER as QUARTER with synonyms=('quarter_of_year','quarterly_interval') comment='The quarter of the year in which a date falls, with 1 representing January to March, 2 representing April to June, 3 representing July to September, and 4 representing October to December.',
		DIM_DATE.WEEK_OF_YEAR as WEEK_OF_YEAR with synonyms=('calendar_week','week_in_year','week_number','week_of_calendar','yearly_week_number') comment='The week of the year, ranging from 1 to 52 or 53, depending on the year, indicating the week number in which a particular date falls.',
		DIM_DATE.YEAR as YEAR with synonyms=('annual_period','calendar_year','fiscal_year','twelve_month_period','yearly_period') comment='The calendar year to which a date belongs.',
		DIM_GEOGRAPHY.CITY_NAME as CITY_NAME comment='The city where a customer or business is located.',
		DIM_GEOGRAPHY.COUNTRY_CODE as COUNTRY_CODE comment='The two-character code representing the country where the data originates, following the ISO 3166-1 alpha-2 standard.',
		DIM_GEOGRAPHY.COUNTRY_NAME as COUNTRY_NAME comment='The full name of the country where a customer, supplier, or other entity is located.',
		DIM_GEOGRAPHY.REGION_NAME as REGION_NAME comment='The geographic region in which a location resides, categorized into one of three broad areas: Northeast, West, or South.',
		DIM_GEOGRAPHY.STATE_CODE as STATE_CODE comment='Unique two-character code identifying the state in the United States where a location resides.',
		DIM_GEOGRAPHY.STATE_NAME as STATE_NAME comment='The full name of the state in the United States.',
		DIM_PRIVATE_BANKER.BANKER_ID as BANKER_ID comment='Unique identifier for a private banker.',
		DIM_PRIVATE_BANKER.EFFECTIVE_DATE as EFFECTIVE_DATE comment='The date when the private banker''s information became effective or was last updated.',
		DIM_PRIVATE_BANKER.EMAIL as EMAIL comment='The email address of the private banker assigned to a client or account.',
		DIM_PRIVATE_BANKER.EXPIRY_DATE as EXPIRY_DATE comment='The date by which the private banker''s relationship with the client is set to expire.',
		DIM_PRIVATE_BANKER.FIRST_NAME as FIRST_NAME comment='The name of the private banker assigned to a client or account.',
		DIM_PRIVATE_BANKER.FULL_NAME as FULL_NAME comment='The full name of the private banker assigned to a client or account.',
		DIM_PRIVATE_BANKER.HIRE_DATE as HIRE_DATE comment='Date when the private banker was hired.',
		DIM_PRIVATE_BANKER.IS_CURRENT as IS_CURRENT comment='Indicates whether the private banker is currently active and assigned to the client.',
		DIM_PRIVATE_BANKER.LAST_NAME as LAST_NAME comment='The name of the private banker assigned to a client.',
		DIM_PRIVATE_BANKER.LICENSE_SERIES as LICENSE_SERIES comment='The LICENSE_SERIES column represents the various professional licenses and certifications held by private bankers, indicating their qualifications and expertise in areas such as securities trading, investment advice, and financial planning.',
		DIM_PRIVATE_BANKER.PHONE as PHONE comment='The phone number of the private banker assigned to a client.',
		DIM_PRIVATE_BANKER.SPECIALIZATION as SPECIALIZATION comment='The area of expertise or focus of a private banker, such as managing client assets, planning for retirement and taxes, or handling estate and trust matters.',
		DIM_PRIVATE_BANKER.TITLE as TITLE comment='The title of the private banker, indicating their level of seniority and role within the organization, such as Senior Private Banker, Private Banking Director, or Private Wealth Advisor.',
		DIM_PRODUCT.MIN_CREDIT_SCORE as MIN_CREDIT_SCORE with synonyms=('base_credit_score','credit_score_floor','lowest_credit_score','minimum_credit_requirement','minimum_credit_threshold') comment='The minimum credit score required for a customer to be eligible for a specific product or service.',
		DIM_PRODUCT.PRODUCT_CATEGORY as PRODUCT_CATEGORY with synonyms=('category_name','product_class','product_family','product_line','product_segment') comment='The type of financial product offered to customers, such as loans or credit cards, which can be further categorized as secured or unsecured.',
		DIM_PRODUCT.PRODUCT_DESCRIPTION as PRODUCT_DESCRIPTION with synonyms=('product_details','product_info','product_overview','product_summary') comment='A brief description of the product, including its features, specifications, and other relevant details that distinguish it from other products.',
		DIM_PRODUCT.PRODUCT_ID as PRODUCT_ID with synonyms=('item_id','product_code','product_identifier','product_number','product_reference','sku') comment='Type of loan product offered by the financial institution.',
		DIM_PRODUCT.PRODUCT_KEY as PRODUCT_KEY comment='Unique identifier for a product in the product dimension table.',
		DIM_PRODUCT.PRODUCT_NAME as PRODUCT_NAME with synonyms=('product_label','product_title') comment='The type of financial product offered by the institution, such as a loan or credit line, used to categorize and analyze product-specific data.',
		DIM_PRODUCT.PRODUCT_SUBTYPE as PRODUCT_SUBTYPE with synonyms=('product_subcategory') comment='The type of loan product offered by the financial institution, such as a loan for purchasing a home, a vehicle, or for personal use.',
		DIM_PRODUCT.PRODUCT_TYPE as PRODUCT_TYPE with synonyms=('item_category','item_class','product_classification') comment='The type of financial product offered by the institution, such as a loan, credit card, or bank account.',
		FACT_CREDIT_CARD.CARD_ID as CARD_ID with synonyms=('account_id','account_number','card_identifier','card_number','credit_card_number') comment='Unique identifier for a credit card account.',
		FACT_CREDIT_CARD.CREDIT_LIMIT as CREDIT_LIMIT with synonyms=('available_credit','credit_allowance','credit_cap','credit_ceiling','credit_maximum','max_credit') comment='The maximum amount of credit that can be used on a credit card account.',
		FACT_CREDIT_CARD.CUSTOMER_KEY as CUSTOMER_KEY with synonyms=('account_holder_id','cardholder_id','client_id','customer_id','customer_identifier') comment='Unique identifier for the customer associated with the credit card.',
		FACT_CREDIT_CARD.LAST_PAYMENT_DATE_KEY as LAST_PAYMENT_DATE_KEY with synonyms=('last_paid_date_key','last_payment_key','payment_history_key','previous_payment_key','recent_payment_date_key') comment='Date key for the most recent payment made on the credit card.',
		FACT_CREDIT_CARD.PAYMENT_DUE_DATE_KEY as PAYMENT_DUE_DATE_KEY with synonyms=('due_date_key','due_timestamp_key','payment_date_key','payment_deadline_key','payment_due_key') comment='Date key for when the credit card payment is due.',
		FACT_CREDIT_CARD.PRODUCT_KEY as PRODUCT_KEY with synonyms=('card_product_id','card_type_key','product_id','product_identifier','product_reference') comment='Unique identifier for the credit card product type.',
		FACT_CREDIT_CARD.SNAPSHOT_DATE_KEY as SNAPSHOT_DATE_KEY with synonyms=('balance_date','date_key','record_date','snapshot_date','timestamp_key') comment='Date key representing when the credit card balance snapshot was taken.',
		FACT_CREDIT_SCORE.CREATED_TIMESTAMP as CREATED_TIMESTAMP comment='The date and time when the credit score record was created.',
		FACT_CREDIT_SCORE.CREDIT_RISK_CATEGORY as CREDIT_RISK_CATEGORY with synonyms=('credit_rating','credit_risk_level','credit_score_segment','credit_status','risk_category','risk_classification','risk_profile') comment='Categorization of a customer''s credit risk based on their credit score, indicating the level of risk associated with lending to them, with categories including Very Good, Good, and Fair.',
		FACT_CREDIT_SCORE.SCORE_DATE as SCORE_DATE comment='Date on which the credit score was recorded or updated.',
		FACT_CREDIT_SCORE.SOURCE_SYSTEM as SOURCE_SYSTEM comment='The system or source that provided the credit score data, either a simulated credit bureau (BUREAU_SIM) or a quarterly simulated credit bureau (BUREAU_SIM_QTR).',
		FACT_CSR_INTERACTION.CALL_DATETIME as CALL_DATETIME comment='Date and time when the customer service interaction occurred.',
		FACT_CSR_INTERACTION.CALL_DESCRIPTION as CALL_DESCRIPTION comment='A brief description of the reason for the customer''s interaction with the customer service representative.',
		FACT_CSR_INTERACTION.CALL_ID as CALL_ID comment='Unique identifier for a customer service interaction, typically a phone call, used to track and manage the interaction from start to resolution.',
		FACT_CSR_INTERACTION.CSR_KEY as CSR_KEY comment='Unique identifier for a customer service representative (CSR) interaction.',
		FACT_CSR_INTERACTION.CUSTOMER_KEY as CUSTOMER_KEY comment='Unique identifier for the customer involved in the interaction.',
		FACT_CSR_INTERACTION.SENTIMENT_LABEL as SENTIMENT_LABEL comment='The sentiment or emotional tone expressed by the customer during the interaction, categorized as positive, negative, or neutral.',
		FACT_LOAN.APPROVAL_DATE_KEY as APPROVAL_DATE_KEY with synonyms=('approval_date_id','approval_timestamp_key','approved_date_reference','date_approved_key','loan_approval_date_ref') comment='The date on which the loan was approved, represented as an integer in the format YYYYMMDD.',
		FACT_LOAN.APPROVAL_REJECTION_DATE as APPROVAL_REJECTION_DATE with synonyms=('approval_date','approval_or_rejection_date','decision_date','final_decision_date','loan_approval_date','loan_rejection_date','loan_status_date','rejection_date') comment='Date on which the loan was either approved or rejected.',
		FACT_LOAN.CUSTOMER_KEY as CUSTOMER_KEY with synonyms=('account_holder_id','borrower_id','client_id','client_identifier','customer_id') comment='Unique identifier for a customer in the loan fact table, linking to the customer dimension table for detailed customer information.',
		FACT_LOAN.LOAN_ID as LOAN_ID with synonyms=('account_number','loan_code','loan_identifier','loan_number','loan_reference') comment='Unique identifier for a loan.',
		FACT_LOAN.LOAN_STATUS as LOAN_STATUS with synonyms=('loan_condition','loan_condition_status','loan_phase','loan_position','loan_position_status','loan_state') comment='The current status of the loan, indicating whether it has been approved or closed.',
		FACT_LOAN.PRODUCT_KEY as PRODUCT_KEY with synonyms=('item_code','item_key','item_number','product_code','product_id','product_identifier') comment='Unique identifier for a specific loan product offered by the financial institution.',
		FACT_TRANSACTION.ACCOUNT_KEY as ACCOUNT_KEY with synonyms=('account_id','account_identifier','account_number','account_reference','financial_account_key') comment='Unique identifier for the account involved in the transaction.',
		FACT_TRANSACTION.ANOMALY_FLAG as ANOMALY_FLAG with synonyms=('anomaly_indicator','fraud_flag','fraud_indicator','risk_flag','suspicious_flag','unusual_flag') comment='Indicates whether the transaction has been flagged as potentially fraudulent or unusual.',
		FACT_TRANSACTION.BRANCH_KEY as BRANCH_KEY with synonyms=('branch_id','branch_identifier','branch_reference','location_id','location_key') comment='Unique identifier for the branch where the transaction occurred.',
		FACT_TRANSACTION.CUSTOMER_KEY as CUSTOMER_KEY with synonyms=('account_holder_id','account_owner_id','client_id','customer_id','customer_identifier') comment='Unique identifier for the customer who made the transaction.',
		FACT_TRANSACTION.TRANSACTION_DATE_KEY as TRANSACTION_DATE_KEY with synonyms=('date_key','timestamp_key','transaction_date_id','transaction_date_reference','transaction_timestamp_key') comment='Date key for when the transaction occurred, in YYYYMMDD format.',
		FACT_TRANSACTION.TRANSACTION_ID as TRANSACTION_ID with synonyms=('payment_id','transaction_code','transaction_identifier','transaction_number','transaction_reference','transfer_id') comment='Unique identifier for each transaction.',
		FACT_TRANSACTION.TRANSACTION_TYPE as TRANSACTION_TYPE with synonyms=('activity_type','payment_type','transaction_category','transaction_classification','transaction_method') comment='The type of transaction, such as deposit, withdrawal, or transfer.',
		VW_ACCOUNT_BALANCE.ACCOUNT_CATEGORY as ACCOUNT_CATEGORY comment='The type of account being tracked, such as a bank account or credit card.',
		VW_ACCOUNT_BALANCE.ACCOUNT_TYPE as ACCOUNT_TYPE comment='The type of account held by the customer, such as a checking account, savings account, or credit card account.',
		VW_ACCOUNT_BALANCE.CUSTOMER_ID as CUSTOMER_ID comment='Unique identifier for a customer in the system, used to track and manage their account balance.',
		VW_ACCOUNT_BALANCE.FIRST_NAME as FIRST_NAME comment='The first name of the account holder.',
		VW_ACCOUNT_BALANCE.LAST_NAME as LAST_NAME comment='The surname of the account holder.',
		VW_CREDIT_CARD_METRICS.CARD_ID as CARD_ID with synonyms=('account_id','account_number','card_identifier','card_number','credit_card_number') comment='Unique identifier for a credit card account.',
		VW_CREDIT_CARD_METRICS.CUSTOMER_KEY as CUSTOMER_KEY with synonyms=('account_holder','account_owner','cardholder','client_id','customer_id','user_id') comment='Unique identifier for a customer in the credit card system, used to link credit card data to individual customer information.',
		VW_CREDIT_CARD_METRICS.SNAPSHOT_DATE_KEY as SNAPSHOT_DATE_KEY with synonyms=('as_of_date','capture_date','data_date','date_key','date_stamp','record_date','snapshot_date','timestamp_key') comment='Date when the credit card metrics were captured, in the format YYYYMMDD.',
		VW_CUSTOMER_TRANSACTION_SUMMARY.CITY as CITY with synonyms=('geographical_location','location','metropolis','municipality','municipality_name','town','urban_area','urban_center') comment='The city where the customer transaction took place.',
		VW_CUSTOMER_TRANSACTION_SUMMARY.CUSTOMER_ID as CUSTOMER_ID with synonyms=('account_holder_id','account_number','client_id','client_number','customer_key','customer_number','user_id') comment='Unique identifier for a customer in the database, used to track and summarize their transactions.',
		VW_CUSTOMER_TRANSACTION_SUMMARY.FULL_NAME as FULL_NAME with synonyms=('customer_full_name','customer_identity','customer_name','full_name','individual_name','name','person_name') comment='The full name of the customer who made the transaction.',
		VW_CUSTOMER_TRANSACTION_SUMMARY.LAST_TRANSACTION_DATE as LAST_TRANSACTION_DATE with synonyms=('last_activity_date','last_transaction_timestamp','latest_transaction_date','most_current_transaction_date','most_recent_transaction_date','recent_transaction_date') comment='The date of the customer''s most recent transaction.'
	)
	with extension (CA='{"tables":[{"name":"DIM_ACCOUNT","dimensions":[{"name":"ACCOUNT_TYPE","sample_values":["Current","Savings"]},{"name":"CUSTOMER_ID","sample_values":["1","2","3"]},{"name":"CUSTOMER_KEY"},{"name":"IS_CURRENT","sample_values":["TRUE"]}],"facts":[{"name":"ACCOUNT_KEY","sample_values":["1","2","3"]}],"time_dimensions":[{"name":"DATE_OF_ACCOUNT_OPENING","sample_values":["2006-05-26","2006-03-02","2015-07-19"]},{"name":"EFFECTIVE_DATE","sample_values":["2025-08-04"]},{"name":"EXPIRY_DATE","sample_values":["9999-12-31"]}]},{"name":"DIM_BRANCH","dimensions":[{"name":"BRANCH_CITY","sample_values":["Indianapolis","Sacramento","San Jose"]},{"name":"BRANCH_ID","sample_values":["159","411","346"]},{"name":"BRANCH_NAME","sample_values":["San Jose, CA - Limited Service","Oklahoma City, OK - ATM Only","Jacksonville, FL - ATM Only"]},{"name":"BRANCH_TYPE","sample_values":["Full Service","Limited Service","ATM Only"]},{"name":"GEOGRAPHY_KEY"}],"facts":[{"name":"BRANCH_KEY","sample_values":["1","2","3"]}]},{"name":"DIM_CSR","dimensions":[{"name":"CSR_ID","sample_values":["CSR001","CSR012","CSR003"]},{"name":"DEPARTMENT","sample_values":["Premium","General"]},{"name":"FIRST_NAME","sample_values":["Sarah","Michael","David"]},{"name":"FULL_NAME","sample_values":["David Park","Michael Chen","Sarah Johnson"]},{"name":"IS_CURRENT","sample_values":["TRUE"]},{"name":"LAST_NAME","sample_values":["Johnson","Chen","Rodriguez"]},{"name":"SPECIALIZATION","sample_values":["Dispute Resolution","Technical Support","Fraud & Security"]}],"facts":[{"name":"CSR_KEY","sample_values":["1","2","3"]}],"time_dimensions":[{"name":"EFFECTIVE_DATE","sample_values":["2025-10-20"]},{"name":"EXPIRY_DATE","sample_values":["9999-12-31"]},{"name":"HIRE_DATE","sample_values":["2019-03-15","2020-01-10","2019-08-22"]}]},{"name":"DIM_CUSTOMER","dimensions":[{"name":"ADDRESS","sample_values":["Address_1","Address_2","Address_3"]},{"name":"CITY","sample_values":["Fort Worth","Louisville","San Diego"]},{"name":"CUSTOMER_ID","sample_values":["1","2","3"]},{"name":"FIRST_NAME","sample_values":["Joshua","Mark","Joseph"]},{"name":"GENDER","sample_values":["Male","Female","Other"]},{"name":"IS_CURRENT","sample_values":["TRUE"]},{"name":"LAST_NAME","sample_values":["Hall","Taylor","Flores"]},{"name":"PRIVATE_BANKER_KEY"}],"facts":[{"name":"AGE","sample_values":["45","47","25"]},{"name":"CUSTOMER_KEY","sample_values":["1","2","3"]}],"time_dimensions":[{"name":"EFFECTIVE_DATE","sample_values":["2025-08-04"]},{"name":"EXPIRY_DATE","sample_values":["9999-12-31"]}]},{"name":"DIM_DATE","dimensions":[{"name":"DAY","sample_values":["1","2","3"]},{"name":"DAY_NAME","sample_values":["Wed","Thu","Fri"]},{"name":"DAY_OF_WEEK","sample_values":["3","4","5"]},{"name":"FISCAL_QUARTER","sample_values":["5","2","3"]},{"name":"FISCAL_YEAR","sample_values":["2019","2020","2021"]},{"name":"IS_HOLIDAY"},{"name":"IS_WEEKEND","sample_values":["FALSE","TRUE"]},{"name":"MONTH","sample_values":["1","2","3"]},{"name":"MONTH_NAME","sample_values":["Jan","Feb","Mar"]},{"name":"QUARTER","sample_values":["1","2","3"]},{"name":"WEEK_OF_YEAR","sample_values":["1","2","3"]},{"name":"YEAR","sample_values":["2020","2021","2022"]}],"time_dimensions":[{"name":"DATE_VALUE","sample_values":["2020-01-01","2020-01-02","2020-01-03"]}]},{"name":"DIM_GEOGRAPHY","dimensions":[{"name":"CITY_NAME","sample_values":["Fort Worth","San Diego","Philadelphia"]},{"name":"COUNTRY_CODE","sample_values":["US"]},{"name":"COUNTRY_NAME","sample_values":["United States"]},{"name":"REGION_NAME","sample_values":["Northeast","West","South"]},{"name":"STATE_CODE","sample_values":["PA","TX","WA"]},{"name":"STATE_NAME","sample_values":["Pennsylvania","New Mexico","Kentucky"]}],"facts":[{"name":"GEOGRAPHY_KEY","sample_values":["402","401","403"]}]},{"name":"DIM_PRIVATE_BANKER","dimensions":[{"name":"BANKER_ID","sample_values":["PB001","PB003","PB002"]},{"name":"EMAIL","sample_values":["catherine.wellington@bank.com","victoria.montgomery@bank.com","alexander.rothschild@bank.com"]},{"name":"FIRST_NAME","sample_values":["Catherine","Alexander","Victoria"]},{"name":"FULL_NAME","sample_values":["Catherine Wellington","Victoria Montgomery","Alexander Rothschild"]},{"name":"IS_CURRENT","sample_values":["TRUE"]},{"name":"LAST_NAME","sample_values":["Rothschild","Montgomery","Wellington"]},{"name":"LICENSE_SERIES","sample_values":["Series 7, Series 65","Series 7, Series 65, CFP","Series 7, Series 66, CFA"]},{"name":"PHONE","sample_values":["858-555-0101","405-555-0102","512-555-0103"]},{"name":"SPECIALIZATION","sample_values":["Estate Planning & Trusts","Retirement & Tax Planning","Investment Management"]},{"name":"TITLE","sample_values":["Senior Private Banker","Private Banking Director","Private Wealth Advisor"]}],"facts":[{"name":"BRANCH_KEY","sample_values":["572","518","534"]},{"name":"PRIVATE_BANKER_KEY","sample_values":["1","2","3"]},{"name":"YEARS_EXPERIENCE","sample_values":["8","13","10"]}],"time_dimensions":[{"name":"EFFECTIVE_DATE","sample_values":["2025-10-21"]},{"name":"EXPIRY_DATE","sample_values":["9999-12-31"]},{"name":"HIRE_DATE","sample_values":["2017-01-10","2015-03-15","2012-08-22"]}]},{"name":"DIM_PRODUCT","dimensions":[{"name":"MIN_CREDIT_SCORE","sample_values":["640","700","660"]},{"name":"PRODUCT_CATEGORY","sample_values":["Secured Loan","Unsecured Loan","Credit Card"]},{"name":"PRODUCT_DESCRIPTION","sample_values":["A personal loan with fixed monthly payments and no collateral required.","Loan designed for financing pre-owned vehicles, typically shorter term.","A mortgage with variable interest rate tied to market index, typically lower starting rates."]},{"name":"PRODUCT_ID","sample_values":["LOAN_HOME","LOAN_AUTO","LOAN_PERSONAL"]},{"name":"PRODUCT_KEY","sample_values":["509","510","508","818"]},{"name":"PRODUCT_NAME","sample_values":["Home Mortgage Loan","Vehicle Financing","Personal Credit Line"]},{"name":"PRODUCT_SUBTYPE","sample_values":["Checking","Savings","Homeowners Insurance"]},{"name":"PRODUCT_TYPE","sample_values":["LOAN","CREDIT_CARD","ACCOUNT"]}]},{"name":"FACT_CREDIT_CARD","dimensions":[{"name":"CARD_ID","sample_values":["1","2","3"]},{"name":"CREDIT_LIMIT","sample_values":["6323.21","9450.12","8918.66"]},{"name":"CUSTOMER_KEY","sample_values":["1","2","3"]},{"name":"LAST_PAYMENT_DATE_KEY","sample_values":["20230510","20230605","20230715"]},{"name":"PAYMENT_DUE_DATE_KEY","sample_values":["20230515","20230612","20230720"]},{"name":"PRODUCT_KEY","sample_values":["1"]},{"name":"SNAPSHOT_DATE_KEY","sample_values":["20250804"]}],"facts":[{"name":"CARD_SNAPSHOT_KEY","sample_values":["1","2","3"]},{"name":"CREDIT_CARD_BALANCE","sample_values":["4524.32","856.70","3242.36"]},{"name":"MINIMUM_PAYMENT_DUE","sample_values":["226.22","42.84","162.12"]},{"name":"REWARDS_POINTS","sample_values":["8142","4842","2209"]}]},{"name":"FACT_CREDIT_SCORE","dimensions":[{"name":"CREDIT_RISK_CATEGORY","sample_values":["Very Good","Good","Fair"]},{"name":"SOURCE_SYSTEM","sample_values":["BUREAU_SIM","BUREAU_SIM_QTR"]}],"facts":[{"name":"CREDIT_SCORE","sample_values":["681","779","656"]},{"name":"CREDIT_SCORE_KEY","sample_values":["98","29","1"]},{"name":"CUSTOMER_KEY","sample_values":["4","2","246"]}],"time_dimensions":[{"name":"CREATED_TIMESTAMP","sample_values":["2025-10-21T08:17:15.208+0000","2025-10-21T08:26:15.849+0000"]},{"name":"SCORE_DATE","sample_values":["2025-10-21","2025-10-01","2023-10-01"]}]},{"name":"FACT_CSR_INTERACTION","dimensions":[{"name":"CALL_DESCRIPTION","sample_values":["Mobile app technical issue","Online banking locked account","Overdraft fee inquiry"]},{"name":"CALL_ID","sample_values":["CALL0137","CALL0488","CALL0034"]},{"name":"CSR_KEY","sample_values":["4","6","5"]},{"name":"CUSTOMER_KEY","sample_values":["132","517","820"]},{"name":"SENTIMENT_LABEL","sample_values":["positive","negative","neutral"]}],"facts":[{"name":"CALL_COUNT","sample_values":["1"]},{"name":"CSR_INTERACTION_KEY","sample_values":["1415","1451","1475"]},{"name":"INTERACTION_DATE_KEY","sample_values":["20250919","20250810","20250921"]},{"name":"NEGATIVE_CALL_COUNT","sample_values":["1","0"]},{"name":"NEUTRAL_CALL_COUNT","sample_values":["1","0"]},{"name":"POSITIVE_CALL_COUNT","sample_values":["1","0"]}],"time_dimensions":[{"name":"CALL_DATETIME","sample_values":["2025-08-17T09:57:11.000+0000","2025-08-12T14:30:48.000+0000","2025-09-21T16:24:17.000+0000"]}]},{"name":"FACT_LOAN","dimensions":[{"name":"APPROVAL_DATE_KEY","sample_values":["20220806","20220829","20221009"]},{"name":"CUSTOMER_KEY","sample_values":["2703","2706","2712"]},{"name":"LOAN_ID","sample_values":["1956","1967","1985"]},{"name":"LOAN_STATUS","sample_values":["Closed","Approved"]},{"name":"PRODUCT_KEY","sample_values":["1"]}],"facts":[{"name":"INTEREST_RATE","sample_values":["7.9000","2.5800","4.0800"]},{"name":"LOAN_AMOUNT","sample_values":["28739.27","35587.78","6589.65"]},{"name":"LOAN_KEY","sample_values":["159301","159302","159303"]},{"name":"LOAN_TERM_MONTHS","sample_values":["48","36","24"]}],"time_dimensions":[{"name":"APPROVAL_REJECTION_DATE","sample_values":["2022-08-06","2022-08-29","2022-10-09"]}]},{"name":"FACT_TRANSACTION","dimensions":[{"name":"ACCOUNT_KEY","sample_values":["1","2","3"]},{"name":"ANOMALY_FLAG","sample_values":["FALSE","TRUE"]},{"name":"BRANCH_KEY","sample_values":["1","2","3"]},{"name":"CUSTOMER_KEY","sample_values":["1","2","3"]},{"name":"TRANSACTION_DATE_KEY","sample_values":["20230101","20230102","20230103"]},{"name":"TRANSACTION_ID","sample_values":["T001","T002","T003"]},{"name":"TRANSACTION_TYPE","sample_values":["DEPOSIT","WITHDRAWAL","TRANSFER_OUT"]}],"facts":[{"name":"ACCOUNT_BALANCE_AFTER_TRANSACTION","sample_values":["15234.56","12876.43","9456.78"]},{"name":"TRANSACTION_AMOUNT","sample_values":["1457.61","1660.99","839.91"]},{"name":"TRANSACTION_KEY","sample_values":["1","2","3"]}]},{"name":"VW_ACCOUNT_BALANCE","dimensions":[{"name":"ACCOUNT_CATEGORY","sample_values":["BANK_ACCOUNT","CREDIT_CARD"]},{"name":"ACCOUNT_TYPE","sample_values":["Checking","Savings","CREDIT_CARD"]},{"name":"CUSTOMER_ID","sample_values":["193","13","254"]},{"name":"FIRST_NAME","sample_values":["Joseph","Donald","Mark"]},{"name":"LAST_NAME","sample_values":["Davis","Gonzalez","Taylor"]}],"facts":[{"name":"ACCOUNT_KEY","sample_values":["154","3","61"]},{"name":"BALANCE_AMOUNT","sample_values":["434846.40","423065.83","390504.79"]},{"name":"BALANCE_DATE_KEY","sample_values":["20250926","20250918","20250927"]},{"name":"CUSTOMER_KEY","sample_values":["154","3","183"]}]},{"name":"VW_CREDIT_CARD_METRICS","dimensions":[{"name":"CARD_ID","sample_values":["1","2","3"]},{"name":"CUSTOMER_KEY","sample_values":["1","2","3"]},{"name":"SNAPSHOT_DATE_KEY","sample_values":["20250804"]}],"facts":[{"name":"CREDIT_CARD_BALANCE","sample_values":["4524.32","856.70","3242.36"]},{"name":"CREDIT_LIMIT","sample_values":["1737.88","1799.36","6112.96"]},{"name":"CREDIT_UTILIZATION_RATIO","sample_values":["2.60335581","0.47611373","0.53040753"]},{"name":"MINIMUM_PAYMENT_DUE","sample_values":["226.22","42.84","162.12"]},{"name":"REWARDS_POINTS","sample_values":["8142","4842","2209"]}]},{"name":"VW_CUSTOMER_TRANSACTION_SUMMARY","dimensions":[{"name":"CITY","sample_values":["Fort Worth","Oklahoma City","Phoenix"]},{"name":"CUSTOMER_ID","sample_values":["1","2","5"]},{"name":"FULL_NAME","sample_values":["Joshua Hall","Mark Taylor","Kevin Lee"]}],"facts":[{"name":"AVG_TRANSACTION_AMOUNT","sample_values":["1457.61000000","1660.99000000","839.91000000"]},{"name":"TOTAL_DEPOSITS","sample_values":["0.00"]},{"name":"TOTAL_TRANSACTION_AMOUNT","sample_values":["1457.61","1660.99","839.91"]},{"name":"TOTAL_TRANSACTIONS","sample_values":["1"]},{"name":"TOTAL_WITHDRAWALS","sample_values":["0.00"]}],"time_dimensions":[{"name":"LAST_TRANSACTION_DATE","sample_values":["2023-12-07","2023-04-27","2023-07-28"]}]}],"relationships":[{"name":"ACCOUNT_TO_CUSTOMER"},{"name":"BRANCH_TO_GEOGRAPHY"},{"name":"CUSTOMER_TO_PRIVATE_BANKER"},{"name":"CREDIT_CARD_SNAPSHOT_TO_DATE"},{"name":"CREDIT_CARD_TO_CUSTOMER"},{"name":"CREDIT_CART_TO_PRODUCT"},{"name":"CREDIT_SCORE_TO_CUSTOMER"},{"name":"CSR_INTERACTION_TO_CSR"},{"name":"CSR_INTERACTION_TO_CUSTOMER"},{"name":"CSR_INTERACTION_TO_DATE"},{"name":"LOAN_APPROVAL_TO_DATE"},{"name":"LOAN_TO_CUSTOMER"},{"name":"LOAN_TO_PRODUCT"},{"name":"BRANCH_TO_TRANSACTION"},{"name":"TRANSACTION_DATE_KEY_JOIN"},{"name":"TRANSACTION_TO_ACCOUNT"},{"name":"TRANSACTION_TO_CUSTOMER"},{"name":"TRANSACTION_TO_DATE"},{"name":"ACCOUNT_BALANCE_TO_ACCOUNT"},{"name":"CC_TO_CUSTID"}],"module_custom_instructions":{"sql_generation":" show all percentages with single digit precision and the % sign, format all dollar values rounded to 2 decimal points and preceded with a $."}}')
    ;


-- =====================================================
-- SECTION 8: CUSTOM STORED PROCEDURES
-- =====================================================
-- Custom tools for extending agent capabilities

-- Email notification procedure for sending alerts and reports
CREATE OR REPLACE PROCEDURE "SEND_EMAIL"("RECIPIENT_EMAIL" VARCHAR, "SUBJECT" VARCHAR, "BODY" VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'send_email'
EXECUTE AS OWNER
AS '
def send_email(session, recipient_email, subject, body):
    try:
        # Escape single quotes in the body
        escaped_body = body.replace("''", "''''")
        
        # Execute the system procedure call
        session.sql(f"""
            CALL SYSTEM$SEND_EMAIL(
                ''BANKING_DEMO_7RIVERS_EMAIL_INTEGRATION'',
                ''{recipient_email}'',
                ''{subject}'',
                ''{escaped_body}'',
                ''text/html''
            )
        """).collect()
        
        return "Email sent successfully"
    except Exception as e:
        return f"Error sending email: {str(e)}"
';

-- =====================================================
-- SECTION 9: SNOWFLAKE INTELLIGENCE AGENT
-- =====================================================
-- AI-powered conversational agent for banking analytics
-- The agent combines Cortex Analyst (text-to-SQL), Cortex Search, and custom tools
-- to provide natural language interaction with the banking data

USE DATABASE SNOWFLAKE_INTELLIGENCE;
USE SCHEMA AGENTS;

CREATE OR REPLACE AGENT BANKING_DEMO_7RIVERS_AGENT
  COMMENT = 'Chat with a demo banking dataset that includes records on customers, branches, transactions, account balances, credit cards, loans and call center logs.'
  PROFILE = '{"display_name":"7Rivers Banking Demo Agent"}'
  FROM SPECIFICATION
  $$
    {"models":{"orchestration":"auto"},"orchestration":{},"instructions":{"response":"As an intelligence analyst, you are working as an assisting 7Rivers National Bank Chief Marketing Officer. When outputting tabular data, always output a corresponding chart to improve visual analytics. Never guess at a user's intent. If their question or prompt is unclear, provide helpful feedback and ask to clarify the question. ","orchestration":"During responses that include marketing related or product related suggestions, always look at the BANKING_DEMO_7RIVERS_MARKETING_SEARCH tool for relevant content and documents to share with the user.","sample_questions":[{"question":"Which customer segments have the highest credit utilization?"},{"question":"What marketing materials do we have for our credit card products?"},{"question":"Analyze customer service call sentiment by product type"}]},"tools":[{"tool_spec":{"type":"cortex_analyst_text_to_sql","name":"BANKING_DEMO_7RIVERS_SV","description":"DIM_ACCOUNT:\n- Database: BANKING_DEMO_7RIVERS_DB, Schema: DW\n- Contains customer account records with account type, status, and opening details. Each record represents a single account with customer linkage and temporal tracking.\n- Enables analysis of account distribution, customer relationships, and account lifecycle management across different account types.\n- LIST OF COLUMNS: ACCOUNT_KEY (unique account identifier), ACCOUNT_TYPE (current/savings classification), CUSTOMER_ID (business customer reference - links to CUSTOMER_ID in DIM_CUSTOMER), CUSTOMER_KEY (foreign key to customer dimension), IS_CURRENT (active status indicator), DATE_OF_ACCOUNT_OPENING (account creation date), EFFECTIVE_DATE (activation date), EXPIRY_DATE (termination date)\n\nDIM_BRANCH:\n- Database: BANKING_DEMO_7RIVERS_DB, Schema: DW\n- Stores branch location information including geographic details, service types, and operational classifications. Each record represents a physical banking location.\n- Supports geographic analysis of banking operations and service distribution across different branch types and locations.\n- LIST OF COLUMNS: BRANCH_KEY (unique branch identifier), BRANCH_CITY (location city), BRANCH_ID (branch code), BRANCH_NAME (facility name), BRANCH_TYPE (service level classification), GEOGRAPHY_KEY (foreign key to geographic dimension)\n\nDIM_CSR:\n- Database: BANKING_DEMO_7RIVERS_DB, Schema: DW\n- Contains customer service representative records with personal details, department assignments, and specializations. Tracks CSR employment and expertise information.\n- Enables analysis of customer service capacity, specialization distribution, and representative performance tracking.\n- LIST OF COLUMNS: CSR_KEY (unique CSR identifier), CSR_ID (CSR code), DEPARTMENT (service level assignment), FIRST_NAME (given name), FULL_NAME (complete name), IS_CURRENT (employment status), LAST_NAME (surname), SPECIALIZATION (expertise area), EFFECTIVE_DATE (assignment start), EXPIRY_DATE (assignment end), HIRE_DATE (employment start)\n\nDIM_CUSTOMER:\n- Database: BANKING_DEMO_7RIVERS_DB, Schema: DW\n- Stores comprehensive customer information including demographics, contact details, and banking relationships. Each record represents an individual customer with personal and account status data.\n- Supports customer segmentation, demographic analysis, and relationship management across the banking portfolio.\n- LIST OF COLUMNS: CUSTOMER_KEY (unique customer identifier), ADDRESS (physical location), CITY (residence city), CUSTOMER_ID (business customer reference), FIRST_NAME (given name), GENDER (demographic classification), IS_CURRENT (active status), LAST_NAME (surname), PRIVATE_BANKER_KEY (foreign key to private banker), AGE (years old), EFFECTIVE_DATE (record activation), EXPIRY_DATE (record termination)\n\nDIM_DATE:\n- Database: BANKING_DEMO_7RIVERS_DB, Schema: DW\n- Comprehensive date dimension providing calendar attributes, fiscal periods, and business day classifications. Serves as central time reference for all temporal analysis.\n- Enables time-based reporting, trend analysis, and fiscal period calculations across all business processes.\n- LIST OF COLUMNS: DATE_KEY (unique date identifier), DAY (day of month), DAY_NAME (weekday name), DAY_OF_WEEK (weekday number), FISCAL_QUARTER (fiscal period), FISCAL_YEAR (fiscal year), IS_HOLIDAY (holiday indicator), IS_WEEKEND (weekend flag), MONTH (month number), MONTH_NAME (month name), QUARTER (calendar quarter), WEEK_OF_YEAR (week number), YEAR (calendar year), DATE_VALUE (actual date)\n\nDIM_GEOGRAPHY:\n- Database: BANKING_DEMO_7RIVERS_DB, Schema: DW\n- Contains geographic location data with city, state, region, and country information. Provides hierarchical geographic classification for location-based analysis.\n- Supports geographic reporting, regional analysis, and location-based business intelligence across banking operations.\n- LIST OF COLUMNS: GEOGRAPHY_KEY (unique geographic identifier), CITY_NAME (city designation), COUNTRY_CODE (country abbreviation), COUNTRY_NAME (country full name), REGION_NAME (regional classification), STATE_CODE (state abbreviation), STATE_NAME (state full name)\n\nDIM_PRIVATE_BANKER:\n- Database: BANKING_DEMO_7RIVERS_DB, Schema: DW\n- Stores private banker information including contact details, qualifications, specializations, and branch assignments. Tracks banker credentials and client relationship management.\n- Enables analysis of private banking capacity, expertise distribution, and client-banker relationship optimization.\n- LIST OF COLUMNS: PRIVATE_BANKER_KEY (unique banker identifier), BANKER_ID (banker code), EMAIL (contact email), FIRST_NAME (given name), FULL_NAME (complete name), IS_CURRENT (employment status), LAST_NAME (surname), LICENSE_SERIES (professional certifications), PHONE (contact number), SPECIALIZATION (expertise area), TITLE (position designation), BRANCH_KEY (branch assignment), YEARS_EXPERIENCE (experience duration), EFFECTIVE_DATE (assignment start), EXPIRY_DATE (assignment end), HIRE_DATE (employment start)\n\nDIM_PRODUCT:\n- Database: BANKING_DEMO_7RIVERS_DB, Schema: DW\n- Contains product catalog information including financial products, categories, descriptions, and eligibility requirements. Each record represents a banking product offering.\n- Supports product analysis, eligibility assessment, and portfolio management across different financial product categories.\n- LIST OF COLUMNS: PRODUCT_KEY (unique product identifier), MIN_CREDIT_SCORE (eligibility threshold), PRODUCT_CATEGORY (product classification), PRODUCT_DESCRIPTION (product details), PRODUCT_ID (product code), PRODUCT_NAME (product title), PRODUCT_SUBTYPE (product subcategory), PRODUCT_TYPE (product type classification)\n\nFACT_CREDIT_CARD:\n- Database: BANKING_DEMO_7RIVERS_DB, Schema: DW\n- Records credit card account snapshots with balances, limits, payment information, and rewards data. Captures point-in-time credit card account status.\n- Enables credit utilization analysis, payment behavior tracking, and rewards program performance measurement.\n- LIST OF COLUMNS: CARD_SNAPSHOT_KEY (unique snapshot identifier), CARD_ID (card account identifier), CREDIT_LIMIT (maximum credit), CUSTOMER_KEY (foreign key to customer), LAST_PAYMENT_DATE_KEY (recent payment date reference), PAYMENT_DUE_DATE_KEY (payment deadline reference), PRODUCT_KEY (foreign key to product), SNAPSHOT_DATE_KEY (snapshot date reference), CREDIT_CARD_BALANCE (outstanding amount), MINIMUM_PAYMENT_DUE (required payment), REWARDS_POINTS (loyalty points)\n\nFACT_CREDIT_SCORE:\n- Database: BANKING_DEMO_7RIVERS_DB, Schema: DW\n- Stores historical credit score data with risk categorization and source system tracking. Maintains credit assessment timeline for customers.\n- Supports credit risk analysis, score trending, and creditworthiness evaluation across customer portfolio.\n- LIST OF COLUMNS: CREDIT_SCORE_KEY (unique score identifier), CREDIT_RISK_CATEGORY (risk classification), SOURCE_SYSTEM (data source), CREDIT_SCORE (creditworthiness score), CUSTOMER_KEY (foreign key to customer), CREATED_TIMESTAMP (record creation time), SCORE_DATE (score assessment date)\n\nFACT_CSR_INTERACTION:\n- Database: BANKING_DEMO_7RIVERS_DB, Schema: DW\n- Records customer service interactions with sentiment analysis, call descriptions, and interaction metrics. Tracks customer-CSR communication events.\n- Enables customer service quality analysis, sentiment tracking, and interaction pattern identification.\n- LIST OF COLUMNS: CSR_INTERACTION_KEY (unique interaction identifier), CALL_DESCRIPTION (interaction reason), CALL_ID (call reference), CSR_KEY (foreign key to CSR), CUSTOMER_KEY (foreign key to customer), SENTIMENT_LABEL (emotional classification), CALL_COUNT (interaction frequency), INTERACTION_DATE_KEY (interaction date reference), NEGATIVE_CALL_COUNT (negative interactions), NEUTRAL_CALL_COUNT (neutral interactions), POSITIVE_CALL_COUNT (positive interactions), CALL_DATETIME (interaction timestamp)\n\nFACT_LOAN:\n- Database: BANKING_DEMO_7RIVERS_DB, Schema: DW\n- Contains loan agreement records with terms, amounts, rates, and approval information. Tracks loan lifecycle from approval to closure.\n- Supports loan portfolio analysis, risk assessment, and lending performance evaluation across different loan products.\n- LIST OF COLUMNS: LOAN_KEY (unique loan identifier), APPROVAL_DATE_KEY (approval date reference), CUSTOMER_KEY (foreign key to customer), LOAN_ID (loan reference), LOAN_STATUS (current state), PRODUCT_KEY (foreign key to product), INTEREST_RATE (loan rate), LOAN_AMOUNT (principal amount), LOAN_TERM_MONTHS (repayment period), APPROVAL_REJECTION_DATE (decision date)\n\nFACT_TRANSACTION:\n- Database: BANKING_DEMO_7RIVERS_DB, Schema: DW\n- Records all financial transactions with amounts, balances, types, and anomaly flags. Provides comprehensive transaction audit trail.\n- Enables transaction analysis, fraud detection, account activity monitoring, and financial behavior assessment.\n- LIST OF COLUMNS: TRANSACTION_KEY (unique transaction identifier), ACCOUNT_KEY (foreign key to account), ANOMALY_FLAG (fraud indicator), BRANCH_KEY (foreign key to branch), CUSTOMER_KEY (foreign key to customer), TRANSACTION_DATE_KEY (transaction date reference), TRANSACTION_ID (transaction reference), TRANSACTION_TYPE (activity classification), ACCOUNT_BALANCE_AFTER_TRANSACTION (post-transaction balance), TRANSACTION_AMOUNT (monetary value)\n\nVW_ACCOUNT_BALANCE:\n- Database: BANKING_DEMO_7RIVERS_DB, Schema: DW\n- Provides consolidated view of customer account balances across bank accounts and credit cards. Combines account and credit card balance information.\n- Enables comprehensive customer financial position analysis and cross-product balance monitoring.\n- LIST OF COLUMNS: ACCOUNT_KEY (account identifier), ACCOUNT_CATEGORY (account classification), ACCOUNT_TYPE (account type), CUSTOMER_ID (customer reference), FIRST_NAME (customer given name), LAST_NAME (customer surname), BALANCE_AMOUNT (current balance), BALANCE_DATE_KEY (balance date reference), CUSTOMER_KEY (foreign key to customer)\n\nVW_CREDIT_CARD_METRICS:\n- Database: BANKING_DEMO_7RIVERS_DB, Schema: DW\n- Aggregated credit card performance metrics including utilization ratios, balances, and rewards. Provides calculated credit card analytics.\n- Supports credit card portfolio management, utilization analysis, and customer credit behavior assessment.\n- LIST OF COLUMNS: CARD_ID (card identifier), CUSTOMER_KEY (foreign key to customer), SNAPSHOT_DATE_KEY (metrics date reference), CREDIT_CARD_BALANCE (outstanding balance), CREDIT_LIMIT (available credit), CREDIT_UTILIZATION_RATIO (usage percentage), MINIMUM_PAYMENT_DUE (required payment), REWARDS_POINTS (loyalty points)\n\nVW_CUSTOMER_TRANSACTION_SUMMARY:\n- Database: BANKING_DEMO_7RIVERS_DB, Schema: DW\n- Summarized customer transaction activity with totals, averages, and geographic information. Provides aggregated customer financial behavior metrics.\n- Enables customer activity analysis, spending pattern identification, and geographic transaction distribution assessment.\n- LIST OF COLUMNS: CITY (customer location), CUSTOMER_ID (customer reference), FULL_NAME (complete customer name), AVG_TRANSACTION_AMOUNT (average spend), TOTAL_DEPOSITS (deposit sum), TOTAL_TRANSACTIONS (activity count), TOTAL_TRANSACTION_AMOUNT (total spend), TOTAL_WITHDRAWALS (withdrawal sum), LAST_TRANSACTION_DATE (recent activity date)\n\nREASONING:\nThis semantic view represents a comprehensive banking data warehouse that integrates customer information, account management, transaction processing, credit services, and customer relationship management. The model connects customers to their various banking products through dimensional relationships, enabling analysis across accounts, loans, credit cards, and service interactions. The fact tables capture transactional and behavioral data while dimension tables provide descriptive context for customers, products, geography, and time periods.\n\nDESCRIPTION:\nThe BANKING_DEMO_7RIVERS_SV semantic view provides a complete banking analytics platform within the BANKING_DEMO_7RIVERS_DB database, integrating customer demographics, account management, transaction history, credit services, and customer relationship data. The model connects customers through dimensional relationships to their banking products including accounts, loans, and credit cards, while tracking service interactions and geographic distribution. Fact tables capture transactional behavior, credit card usage, loan agreements, and customer service interactions, supported by comprehensive dimension tables for customers, products, branches, dates, and geography. This integrated view enables analysis of customer financial behavior, product performance, risk assessment, and service quality across the entire banking portfolio."}},{"tool_spec":{"type":"cortex_search","name":"BANKING_DEMO_7RIVERS_CALL_CENTER_SEARCH","description":"This tool provides access to banking call center logs in Cortex Search. The logs include CSR Rep ID and Customer ID as well as description of the call as indexed columns."}},{"tool_spec":{"type":"cortex_search","name":"BANKING_DEMO_7RIVERS_MARKETING_SEARCH","description":"This tool provides access to marketing materials for the bank."}},{"tool_spec":{"type":"generic","name":"SEND_EMAIL","description":"PROCEDURE/FUNCTION DETAILS:\n- Type: Custom User-Defined Function\n- Language: Python 3.12\n- Signature: (RECIPIENT_EMAIL VARCHAR, SUBJECT VARCHAR, BODY VARCHAR)\n- Returns: VARCHAR (success/error message)\n- Execution: OWNER privileges with CALLED ON NULL INPUT\n- Volatility: VOLATILE (produces different results on each call)\n- Primary Function: Email notification delivery\n- Target: External email recipients via Snowflake's email integration\n- Error Handling: Exception catching with descriptive error messages\n\nDESCRIPTION:\nThis custom email function provides automated email notification capabilities within Snowflake by wrapping the system's SEND_EMAIL procedure with enhanced error handling and input sanitization. The function accepts recipient email addresses, subject lines, and HTML-formatted message bodies, automatically escaping special characters to prevent SQL injection and formatting issues. It executes with owner privileges and requires the 'email_integration' to be properly configured in your Snowflake environment. The function returns clear success or failure messages, making it ideal for integration into data pipelines, alerting systems, and automated reporting workflows. Users should ensure they have appropriate email integration permissions and that the email_integration object is configured before using this function.\n\nUSAGE SCENARIOS:\n- Automated data pipeline notifications: Send alerts when ETL processes complete, fail, or encounter data quality issues\n- Scheduled reporting delivery: Automatically email summary reports, dashboards, or data extracts to stakeholders on a regular basis\n- System monitoring and alerts: Notify administrators of system events, performance thresholds, or maintenance requirements through stored procedures or tasks","input_schema":{"type":"object","properties":{"body":{"description":"Use HTML-Syntax for this. If the content you get is in markdown, translate it to HTML. If body is not provided, summarize the last question and use that as content for the email.","type":"string"},"recipient_email":{"description":"Ask the user for their email address. If not provided, send it to it@7riversinc.com","type":"string"},"subject":{"description":" If subject is not provided, use \"Snowflake Intelligence\".","type":"string"}},"required":["body","recipient_email","subject"]}}}],"tool_resources":{"BANKING_DEMO_7RIVERS_CALL_CENTER_SEARCH":{"max_results":10,"search_service":"BANKING_DEMO_7RIVERS_DB.DW.BANKING_DEMO_7RIVERS_CALL_CENTER_SEARCH","title_column":"CALL_DESCRIPTION"},"BANKING_DEMO_7RIVERS_MARKETING_SEARCH":{"id_column":"FILE_URL","max_results":10,"search_service":"BANKING_DEMO_7RIVERS_DB.DW.BANKING_DEMO_7RIVERS_MARKETING_SEARCH","title_column":"RELATIVE_PATH"},"BANKING_DEMO_7RIVERS_SV":{"execution_environment":{"query_timeout":120,"type":"warehouse","warehouse":""},"semantic_view":"BANKING_DEMO_7RIVERS_DB.DW.BANKING_DEMO_7RIVERS_SV"},"SEND_EMAIL":{"execution_environment":{"type":"warehouse","warehouse":"BANKING_DEMO_7RIVERS_WH"},"identifier":"BANKING_DEMO_7RIVERS_DB.DW.SEND_EMAIL","name":"SEND_EMAIL(VARCHAR, VARCHAR, VARCHAR)","type":"procedure"}}}
  $$
;