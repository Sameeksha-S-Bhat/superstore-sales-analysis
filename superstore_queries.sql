-- ============================================================
-- SUPERSTORE SALES ANALYSIS — SQL QUERIES
-- Table name: superstore
-- ============================================================

create database superstore_database;
create table superstore;


-- STEP 1 — EXPLORE THE TABLE

-- See structure of table
DESCRIBE superstore;

-- See structure of table
DESCRIBE superstore;

-- See sample data
SELECT * FROM superstore LIMIT 10;

-- Count total rows
SELECT COUNT(*) AS total_rows FROM superstore;

-- Date range of data
SELECT 
    MIN(`Order Date`) AS earliest_order,
    MAX(`Order Date`) AS latest_order
FROM superstore;

-- QUERY 1 — OVERALL BUSINESS SUMMARY
select
    COUNT(DISTINCT `Order ID`)    AS total_orders,
    COUNT(DISTINCT `Customer ID`) AS total_customers,
    COUNT(DISTINCT `Product ID`)  AS total_products,
    ROUND(SUM(Sales), 2)          AS total_revenue,
    ROUND(SUM(Profit), 2)         AS total_profit,
    ROUND(SUM(Profit)/SUM(Sales)*100, 2) AS profit_margin_pct,
    ROUND(AVG(Sales), 2)          AS avg_order_value
FROM superstore;

-- QUERY 2 — REVENUE AND PROFIT BY CATEGORY
-- GROUP BY on Category column
-- Shows which product category is most valuable

select
    Category,
    COUNT(*)                             AS total_rows,
    ROUND(SUM(Sales), 2)                 AS total_revenue,
    ROUND(SUM(Profit), 2)                AS total_profit,
    ROUND(SUM(Profit)/SUM(Sales)*100, 2) AS profit_margin_pct,
    ROUND(AVG(Discount)*100, 2)          AS avg_discount_pct
FROM superstore
GROUP BY Category
ORDER BY total_revenue DESC;

-- QUERY 3 — TOP 10 CUSTOMERS BY REVENUE
-- ORDER BY + LIMIT pattern
-- Shows who your most valuable customers are
SELECT 
    `Customer ID`,
    `Customer Name`,
    Segment,
    COUNT(DISTINCT `Order ID`)  AS total_orders,
    ROUND(SUM(Sales), 2)        AS total_revenue,
    ROUND(SUM(Profit), 2)       AS total_profit,
    ROUND(AVG(Sales), 2)        AS avg_order_value
FROM superstore
GROUP BY `Customer ID`, `Customer Name`, Segment
ORDER BY total_revenue DESC
LIMIT 10;

-- QUERY 4 — MONTHLY REVENUE TREND
-- DATE_FORMAT + GROUP BY for time series analysis
-- Shows seasonality and growth patterns
SELECT 
    DATE_FORMAT(`Order Date`, '%Y-%m')  AS year_month_,
    COUNT(DISTINCT `Order ID`)          AS total_orders,
    ROUND(SUM(Sales), 2)                AS monthly_revenue,
    ROUND(SUM(Profit), 2)               AS monthly_profit
FROM superstore
GROUP BY DATE_FORMAT(`Order Date`, '%Y-%m')
ORDER BY year_month_;

-- QUERY 5 — REVENUE BY REGION AND CATEGORY
-- Multiple GROUP BY columns
-- Shows which region + category combination performs best
SELECT 
    Region,
    Category,
    ROUND(SUM(Sales), 2)   AS total_revenue,
    ROUND(SUM(Profit), 2)  AS total_profit,
    COUNT(*)               AS total_orders
FROM superstore
GROUP BY Region, Category
ORDER BY Region, total_revenue DESC;

-- QUERY 6 — CUSTOMERS WHO SPENT ABOVE AVERAGE
-- Subquery inside WHERE
-- Pattern: find rows that exceed a calculated threshold
-- First understand what average customer spend is
SELECT ROUND(AVG(customer_total), 2) AS avg_customer_spend
FROM (
    SELECT `Customer ID`, SUM(Sales) AS customer_total
    FROM superstore
    GROUP BY `Customer ID`
) AS customer_summary;

-- Now find customers above that average
SELECT 
    `Customer Name`,
    Segment,
    ROUND(SUM(Sales), 2) AS total_spend
FROM superstore
GROUP BY `Customer ID`, `Customer Name`, Segment
HAVING SUM(Sales) > (
    -- Subquery calculates average customer spend
    SELECT AVG(customer_total)
    FROM (
        SELECT `Customer ID`, SUM(Sales) AS customer_total
        FROM superstore
        GROUP BY `Customer ID`
    ) AS temp
)
ORDER BY total_spend DESC;

-- QUERY 7 — MONTH OVER MONTH REVENUE GROWTH
-- LAG Window Function
-- Shows how revenue changed from previous month

SELECT 
    year_month_,
    monthly_revenue,
    -- LAG gets previous row's value
    LAG(monthly_revenue) OVER (ORDER BY year_month_) AS prev_month_revenue,
    
    -- Calculate change in dollars
    ROUND(monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY year_month_), 2) AS revenue_change,
    
    -- Calculate percentage change
    ROUND(
        (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY year_month_)) * 100.0 /
        NULLIF(LAG(monthly_revenue) OVER (ORDER BY year_month_), 0)
    , 2) AS growth_pct

FROM (
    -- Inner query creates monthly totals first
    SELECT 
        DATE_FORMAT(`Order Date`, '%Y-%m') AS year_month_,
        ROUND(SUM(Sales), 2) AS monthly_revenue
    FROM superstore
    GROUP BY DATE_FORMAT(`Order Date`, '%Y-%m')
) AS monthly_data
ORDER BY year_month_;

-- NULLIF prevents division by zero error on first month
-- LAG looks back 1 row — so first month has NULL for previous

-- QUERY 8 — RANK PRODUCTS BY PROFIT WITHIN CATEGORY
-- RANK Window Function with PARTITION BY
-- Classic window function interview question

SELECT * FROM (
    SELECT 
        Category,
        `Sub-Category`,
        ROUND(SUM(Sales), 2)   AS total_revenue,
        ROUND(SUM(Profit), 2)  AS total_profit,
        
        -- RANK within each category by profit
        -- PARTITION BY = restart ranking for each category
        RANK() OVER (
            PARTITION BY Category 
            ORDER BY SUM(Profit) DESC
        ) AS profit_rank
        
    FROM superstore
    GROUP BY Category, `Sub-Category`
) ranked_products
WHERE profit_rank <= 3  -- top 3 per category
ORDER BY Category, profit_rank;

-- QUERY 9 — STATES WITH NEGATIVE TOTAL PROFIT
-- WHERE + GROUP BY + HAVING combination
-- Find underperforming locations

SELECT 
    State,
    Region,
    COUNT(DISTINCT `Order ID`)  AS total_orders,
    ROUND(SUM(Sales), 2)        AS total_revenue,
    ROUND(SUM(Profit), 2)       AS total_profit,
    ROUND(SUM(Profit)/SUM(Sales)*100, 2) AS profit_margin_pct,
    ROUND(AVG(Discount)*100, 2) AS avg_discount_pct
FROM superstore
GROUP BY State, Region
HAVING SUM(Profit) < 0  -- only states losing money
ORDER BY total_profit ASC;  -- worst first

-- These states are losing money overall
-- Business question: should we exit these markets or change strategy?


-- QUERY 10 — TOP CUSTOMER PER REGION
-- ROW_NUMBER Window Function
-- Most asked window function pattern in interviews

SELECT * FROM (
    SELECT 
        Region,
        `Customer Name`,
        ROUND(SUM(Sales), 2)   AS total_revenue,
        COUNT(DISTINCT `Order ID`) AS total_orders,
        
        -- ROW_NUMBER within each region ordered by revenue
        ROW_NUMBER() OVER (
            PARTITION BY Region 
            ORDER BY SUM(Sales) DESC
        ) AS rn
        
    FROM superstore
    GROUP BY Region, `Customer ID`, `Customer Name`
) ranked_customers
WHERE rn = 1  -- only the #1 customer per region
ORDER BY total_revenue DESC;

-- This gives you the single highest spending customer in each region
-- Use RANK() instead of ROW_NUMBER() if you want ties included


-- QUERY 11 — SHIPPING ANALYSIS
-- How quickly are orders being shipped?

SELECT 
    `Ship Mode`,
    COUNT(*) AS total_orders,
    
    -- DATEDIFF calculates days between ship date and order date
    ROUND(AVG(DATEDIFF(`Ship Date`, `Order Date`)), 1) AS avg_shipping_days,
    MIN(DATEDIFF(`Ship Date`, `Order Date`))           AS min_shipping_days,
    MAX(DATEDIFF(`Ship Date`, `Order Date`))           AS max_shipping_days,
    ROUND(SUM(Sales), 2)                               AS total_revenue
    
FROM superstore
GROUP BY `Ship Mode`
ORDER BY avg_shipping_days;


-- QUERY 12 — YEARLY GROWTH WITH YEAR OVER YEAR %
-- Combining DATE functions + LAG + subquery
-- Shows business growth trajectory

SELECT 
    order_year,
    total_revenue,
    total_profit,
    total_orders,
    
    -- Year over year revenue growth
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY order_year)) * 100.0 /
        NULLIF(LAG(total_revenue) OVER (ORDER BY order_year), 0)
    , 2) AS revenue_growth_pct,
    
    -- Year over year profit growth
    ROUND(
        (total_profit - LAG(total_profit) OVER (ORDER BY order_year)) * 100.0 /
        NULLIF(LAG(total_profit) OVER (ORDER BY order_year), 0)
    , 2) AS profit_growth_pct

FROM (
    SELECT 
        YEAR(`Order Date`)         AS order_year,
        ROUND(SUM(Sales), 2)       AS total_revenue,
        ROUND(SUM(Profit), 2)      AS total_profit,
        COUNT(DISTINCT `Order ID`) AS total_orders
    FROM superstore
    GROUP BY YEAR(`Order Date`)
) yearly_data
ORDER BY order_year;



-- QUERY 13 — DISCOUNT IMPACT ON PROFIT
-- CASE WHEN to create discount buckets
-- Shows at what discount level profit turns negative

SELECT 
    discount_band,
    COUNT(*) AS total_orders,
    ROUND(AVG(Sales), 2)   AS avg_revenue,
    ROUND(AVG(Profit), 2)  AS avg_profit,
    ROUND(SUM(Profit), 2)  AS total_profit,
    
    -- What % of orders in this band are losses?
    ROUND(
        SUM(CASE WHEN Profit < 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
    , 2) AS loss_order_pct
    
FROM (
    SELECT 
        Sales, Profit,
        CASE 
            WHEN Discount = 0          THEN '0% - No Discount'
            WHEN Discount <= 0.10      THEN '1-10%'
            WHEN Discount <= 0.20      THEN '11-20%'
            WHEN Discount <= 0.30      THEN '21-30%'
            WHEN Discount <= 0.40      THEN '31-40%'
            WHEN Discount <= 0.50      THEN '41-50%'
            ELSE                            'Above 50%'
        END AS discount_band
    FROM superstore
) banded
GROUP BY discount_band
ORDER BY discount_band;

-- Key insight: find which band is where profit first turns negative
-- That's your maximum recommended discount threshold


-- QUERY 14 — CUSTOMER SEGMENTATION ANALYSIS
-- Understand Consumer vs Corporate vs Home Office

SELECT 
    Segment,
    COUNT(DISTINCT `Customer ID`)  AS unique_customers,
    COUNT(DISTINCT `Order ID`)     AS total_orders,
    ROUND(SUM(Sales), 2)           AS total_revenue,
    ROUND(AVG(Sales), 2)           AS avg_order_value,
    ROUND(SUM(Profit)/SUM(Sales)*100, 2) AS profit_margin_pct,
    
    -- Revenue per customer (loyalty metric)
    ROUND(SUM(Sales) / COUNT(DISTINCT `Customer ID`), 2) AS revenue_per_customer
    
FROM superstore
GROUP BY Segment
ORDER BY total_revenue DESC;



-- Combines multiple metrics per customer
-- Can export this for Power BI dashboard

SELECT 
    `Customer ID`,
    `Customer Name`,
    Segment,
    Region,
    COUNT(DISTINCT `Order ID`)     AS total_orders,
    ROUND(SUM(Sales), 2)           AS lifetime_revenue,
    ROUND(SUM(Profit), 2)          AS lifetime_profit,
    ROUND(AVG(Sales), 2)           AS avg_order_value,
    MIN(`Order Date`)              AS first_order_date,
    MAX(`Order Date`)              AS last_order_date,
    DATEDIFF(MAX(`Order Date`), MIN(`Order Date`)) AS customer_lifespan_days,
    
    -- Rank customer within their segment by revenue
    RANK() OVER (
        PARTITION BY Segment 
        ORDER BY SUM(Sales) DESC
    ) AS rank_in_segment

FROM superstore
GROUP BY `Customer ID`, `Customer Name`, Segment, Region
ORDER BY lifetime_revenue DESC;

-- This shows top 3 most profitable sub-categories in each category
-- Real use: decide which products to promote

