# 7Rivers Banking Demo

## Overview

This repository contains a comprehensive banking demonstration environment showcasing **Snowflake Intelligence** and **Cortex AI** capabilities. The demo represents a fictional **7Rivers National Bank** with a complete data warehouse implementation, AI-powered search services, and conversational analytics through Snowflake's Intelligence Agent.

[7Rivers Conversational Analytics Overview](https://public7rivers.blob.core.windows.net/banking-demo/demo_documentation/7Rivers%20Conversational%20Analytics%20for%20Banking%20Overview.pdf)

[7Rivers Conversational Analytics Demo Banking Narrative](https://public7rivers.blob.core.windows.net/banking-demo/demo_documentation/7Rivers%20Conversational%20Analytics%20Demo%20for%20Banking%20Narrative.pdf)

## What's Included

### AI & Intelligence Features

#### 1. Cortex Search Services
- **Call Center Search** - Semantic search over customer service call transcripts
- **Marketing Search** - Product information and marketing document retrieval

#### 2. Semantic View (Cortex Analyst)
A comprehensive semantic model enabling natural language querying:
- 15+ tables with business-friendly synonyms
- Detailed column descriptions and sample values
- Relationship definitions for accurate joins
- Custom instructions for SQL generation (formatting, precision)

#### 3. Snowflake Intelligence Agent
An AI-powered conversational agent that combines:
- **Cortex Analyst** - Text-to-SQL for analytics queries
- **Cortex Search** - Semantic search over documents and transcripts
- **Custom Tools** - Email notifications and reporting capabilities

**Agent Capabilities:**
- Answer questions about customer behavior and trends
- Find relevant marketing materials
- Search call center logs for customer issues
- Send email reports and notifications
- Generate visualizations and charts

### Data Model
The demo implements a dimensional data warehouse as the underlying data foundation:

**Dimension Tables:**
- **DIM_CUSTOMER** - Customer demographics and contact information
- **DIM_ACCOUNT** - Customer account records with SCD Type 2 tracking
- **DIM_BRANCH** - Branch locations and geographic information
- **DIM_GEOGRAPHY** - Geographic hierarchies (city, state, region)
- **DIM_PRIVATE_BANKER** - Private banking professionals and their qualifications
- **DIM_CSR** - Customer service representatives and specializations
- **DIM_PRODUCT** - Banking products (loans, credit cards, accounts)
- **DIM_DATE** - Date dimension for temporal analysis

**Fact Tables:**
- **FACT_TRANSACTION** - Banking transactions with anomaly detection flags
- **FACT_CREDIT_CARD** - Credit card balance snapshots and usage metrics
- **FACT_LOAN** - Loan agreements and terms
- **FACT_CREDIT_SCORE** - Customer credit score history
- **FACT_CSR_INTERACTION** - Customer service interactions with sentiment analysis

**Analytical Views:**
- Account balance summaries (bank accounts and credit cards)
- Credit card utilization metrics
- Customer transaction summaries
- Branch performance analytics
- Regional analysis
- Monthly transaction trends
- Anomaly monitoring dashboards

## Getting Started

### Prerequisites
- Snowflake account with:
  - Snowflake Intelligence features enabled
  - Cortex AI services available
  - ACCOUNTADMIN role access

### Installation

1. **Run the Setup Script**
   ```sql
   -- Execute as ACCOUNTADMIN
   -- Script location: banking_demo_setup.sql
   ```

2. **The script will create:**
   - Role: `BANKING_DEMO_7RIVERS_ROLE`
   - Database: `BANKING_DEMO_7RIVERS_DB`
   - Schema: `DW`
   - Warehouse: `BANKING_DEMO_7RIVERS_WH`
   - All tables, views, and AI services
   - Intelligence Agent: `BANKING_DEMO_7RIVERS_AGENT`

3. **Data Loading**
   - Data is automatically loaded from Azure blob storage
   - All dimension and fact tables are populated
   - Staging tables are loaded with raw data

### Usage

#### Querying the Data
```sql
USE ROLE BANKING_DEMO_7RIVERS_ROLE;
USE DATABASE BANKING_DEMO_7RIVERS_DB;
USE SCHEMA DW;
USE WAREHOUSE BANKING_DEMO_7RIVERS_WH;

-- Example: View customer transaction summary
SELECT * FROM VW_CUSTOMER_TRANSACTION_SUMMARY LIMIT 10;

-- Example: Analyze credit card utilization
SELECT * FROM VW_CREDIT_CARD_METRICS
WHERE CREDIT_UTILIZATION_RATIO > 0.8;
```

#### Using Cortex Search
```sql
-- Search call center logs
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
      'BANKING_DEMO_7RIVERS_CALL_CENTER_SEARCH',
      '{
         "query": "Account balance inquiry",
         "limit": 5
      }'
  )
)['results'] as results;
```

#### Interacting with the Agent
Access the agent through Snowsight UI or programmatically:

**Example Questions:**
- "Which customer segments have the highest credit utilization?"
- "What marketing materials do we have for our credit card products?"
- "Analyze customer service call sentiment by product type"
- "Show me transaction trends over the last 6 months"
- "Find customers with declining credit scores"

## Architecture

### Data Flow
```
External Stage (Azure)
    ↓
Staging Tables (STG_*)
    ↓
Dimension & Fact Tables
    ↓
Analytical Views (VW_*)
    ↓
Semantic View + Cortex Search
    ↓
Intelligence Agent
```

### Key Components

1. **External Stage** - Public Azure blob storage with demo data files
   - azure://public7rivers.blob.core.windows.net/banking-demo/
2. **Data Warehouse** - Star schema with dimension and fact tables
3. **Cortex Services**
   - Search: Vector embeddings for semantic search
   - Analyst: Natural language to SQL translation
4. **Intelligence Agent** - Orchestrated AI assistant with multiple tools
5. **Custom Procedures** - Email notifications via Python stored procedures

## Demo Scenarios

### 1. Customer Analytics
- Identify high-value customers
- Analyze transaction patterns
- Monitor credit utilization trends
- Track customer lifetime value

### 2. Branch Performance
- Compare branch transaction volumes
- Analyze regional performance
- Identify underperforming locations
- Optimize branch network

### 3. Customer Service Intelligence
- Analyze call sentiment trends
- Identify common customer issues
- Track CSR performance
- Improve service quality

### 4. Risk & Compliance
- Monitor transaction anomalies
- Track credit score changes
- Identify potential fraud
- Assess loan portfolio risk

### 5. Marketing & Product
- Retrieve product information
- Access marketing materials
- Analyze product adoption
- Cross-sell opportunities

## Technical Details

### Database Objects
- **Database:** BANKING_DEMO_7RIVERS_DB
- **Schema:** DW
- **Warehouse:** BANKING_DEMO_7RIVERS_WH (Small, auto-suspend 60s)
- **Tables:** 15 (8 dimensions, 5 facts, 2 staging)
- **Views:** 6 analytical views
- **Search Services:** 2 Cortex Search services
- **Semantic Views:** 1 comprehensive model
- **Procedures:** 1 (email notifications)
- **Agents:** 1 Intelligence Agent

### Data Volume
Sample data includes:
- ~5,000 customers
- ~100 branches across US regions
- ~15,000 transactions
- ~3,000 credit card accounts
- ~2,500 loan records
- ~500 customer service interactions

## Use Cases for Consulting Partners

This demo is ideal for showcasing:
- **Modern Data Warehousing** - Dimensional modeling, SCD Type 2
- **AI-Powered Analytics** - Natural language querying, semantic search
- **Conversational BI** - Agent-based interaction patterns
- **Banking Analytics** - Industry-specific KPIs and metrics
- **Data Governance** - Role-based access, semantic layer
- **Advanced SQL** - Window functions, CTEs, complex joins

## Support & Customization

### Best Practices
- Use the provided role (`BANKING_DEMO_7RIVERS_ROLE`) for access control
- Monitor warehouse usage and adjust size as needed
- Refresh search services if data is updated
- Test agent responses before customer demos
- Review semantic view for accuracy

## License & Disclaimer

This is a **demonstration environment** with **fictional data** representing 7Rivers National Bank. All customer names, account numbers, and transactions are synthetically generated for educational and demonstration purposes only.

**Not for production use.**

---

**7Rivers, Inc.**
Copyright © 2025-Present 7Rivers, Inc.
All Rights Reserved
