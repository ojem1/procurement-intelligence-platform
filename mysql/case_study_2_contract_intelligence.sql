-- ============================================================
-- PROJECT 2: STRATEGIC CONTRACT OPTIMIZATION
-- VERSION 3 - PROCUREMENT DECISION ENGINE
-- INCORPORATES: CoV Volatility, Supplier Concentration, 
-- Phase-Out Override, Contract Type Recommendations, 
-- Savings Opportunity, and Growth Quality Signals
-- Which Products Should Be Purchased Under Long-Term Contracts?
-- ============================================================

WITH base_metrics AS (
    -- ============================================================
    -- STEP 1: PRODUCT-YEAR METRICS (2023-2025)
    -- ============================================================
    SELECT
        il.description AS product_name,
        YEAR(i.invoice_date) AS purchase_year,
        ROUND(SUM(il.line_total), 2) AS total_spend,
        COUNT(DISTINCT i.invoice_id) AS invoice_count,
        COUNT(DISTINCT i.po_id) AS po_frequency,
        COUNT(DISTINCT DATE_FORMAT(i.invoice_date, '%Y-%m')) AS months_purchased,
        
        -- ============================================================
        -- VOLATILITY: COEFFICIENT OF VARIATION (CV)
        -- Robust to outliers. CV = (STDDEV / AVG) × 100
        -- ============================================================
        ROUND(
            (STDDEV_POP(il.unit_price) / NULLIF(AVG(il.unit_price), 0)) * 100, 
        2) AS price_cv,
        
        -- ============================================================
        -- SUPPLIER CONCENTRATION (per product per year)
        -- ============================================================
        COUNT(DISTINCT v.vendor_id) AS supplier_count
        
    FROM invoice_line_items_july_2026 il
    JOIN invoice_july_2026 i 
        ON il.invoice_id = i.invoice_id
    JOIN vendors_july_2026 v 
        ON i.vendor_id = v.vendor_id
    WHERE v.currency = 'USD'
      AND YEAR(i.invoice_date) BETWEEN 2023 AND 2025
    GROUP BY 
        il.description,
        YEAR(i.invoice_date)
),

-- ============================================================
-- STEP 2: AGGREGATE BY PRODUCT (ALL YEARS)
-- ============================================================
product_aggregate AS (
    SELECT
        product_name,
        
        -- Average annual spend
        ROUND(AVG(total_spend), 2) AS avg_annual_spend,
        
        -- Year-by-year spend
        MAX(CASE WHEN purchase_year = 2025 THEN total_spend ELSE 0 END) AS spend_2025,
        MAX(CASE WHEN purchase_year = 2024 THEN total_spend ELSE 0 END) AS spend_2024,
        MAX(CASE WHEN purchase_year = 2023 THEN total_spend ELSE 0 END) AS spend_2023,
        
        -- Frequency
        MAX(CASE WHEN purchase_year = 2025 THEN po_frequency ELSE 0 END) AS po_frequency_2025,
        ROUND(AVG(po_frequency), 0) AS avg_po_frequency,
        
        -- Consistency
        MAX(CASE WHEN purchase_year = 2025 THEN months_purchased ELSE 0 END) AS months_purchased_2025,
        ROUND(AVG(months_purchased), 0) AS avg_months_purchased,
        
        -- Volatility (using most recent year's CV)
        MAX(CASE WHEN purchase_year = 2025 THEN price_cv ELSE NULL END) AS price_cv_2025,
        ROUND(AVG(price_cv), 2) AS avg_price_cv,
        
        -- Supplier Concentration (using most recent year)
        MAX(CASE WHEN purchase_year = 2025 THEN supplier_count ELSE NULL END) AS supplier_count_2025,
        ROUND(AVG(supplier_count), 0) AS avg_supplier_count,
        
        -- Year-over-year growth (2024 → 2025)
        ROUND(
            (MAX(CASE WHEN purchase_year = 2025 THEN total_spend ELSE 0 END) - 
             MAX(CASE WHEN purchase_year = 2024 THEN total_spend ELSE 0 END)) / 
            NULLIF(MAX(CASE WHEN purchase_year = 2024 THEN total_spend ELSE 0 END), 0) * 100,
        2) AS yoy_growth_pct,
        
        -- Years of data
        COUNT(DISTINCT purchase_year) AS years_of_data
        
    FROM base_metrics
    GROUP BY product_name
    HAVING COUNT(DISTINCT purchase_year) >= 2
),

-- ============================================================
-- STEP 3: GLOBAL MAXIMUMS FOR NORMALIZATION
-- ============================================================
global_max AS (
    SELECT
        MAX(avg_annual_spend) AS max_spend,
        MAX(avg_po_frequency) AS max_frequency,
        MAX(avg_months_purchased) AS max_months,
        MAX(avg_price_cv) AS max_cv,
        MAX(avg_supplier_count) AS max_supplier_count
    FROM product_aggregate
),

-- ============================================================
-- STEP 4: CALCULATE SCORES WITH NEW WEIGHTS
-- ============================================================
scored_products AS (
    SELECT
        pa.product_name,
        pa.avg_annual_spend,
        pa.spend_2025,
        pa.spend_2024,
        pa.spend_2023,
        pa.avg_po_frequency,
        pa.po_frequency_2025,
        pa.avg_months_purchased,
        pa.months_purchased_2025,
        pa.price_cv_2025,
        pa.avg_price_cv,
        pa.avg_supplier_count,
        pa.supplier_count_2025,
        pa.yoy_growth_pct,
        pa.years_of_data,
        
        -- ============================================================
        -- NEW WEIGHTED SCORES (30/25/20/15/10)
        -- ============================================================
        
        -- SPEND SCORE (Max 30 points - reduced from 40)
        ROUND((pa.avg_annual_spend / gm.max_spend) * 30, 2) AS spend_score,
        
        -- FREQUENCY SCORE (Max 25 points)
        ROUND((pa.avg_po_frequency / gm.max_frequency) * 25, 2) AS frequency_score,
        
        -- CONSISTENCY SCORE (Max 20 points)
        ROUND((pa.avg_months_purchased / 12) * 20, 2) AS consistency_score,
        
        -- VOLATILITY SCORE (Max 15 points)
        -- INVERTED: Lower CV = higher score (stable pricing = safer contract)
        ROUND(
            COALESCE((1 - (pa.avg_price_cv / gm.max_cv)) * 15, 15),
        2) AS volatility_score,
        
        -- SUPPLIER CONCENTRATION SCORE (Max 10 points)
        -- Fewer suppliers = higher dependency = stronger contract incentive
        ROUND(
            (1 - (pa.avg_supplier_count / gm.max_supplier_count)) * 10,
        2) AS concentration_score,
        
        -- ============================================================
        -- TOTAL CONTRACT PRIORITY SCORE (Out of 100)
        -- ============================================================
        ROUND(
            (pa.avg_annual_spend / gm.max_spend) * 30 +
            (pa.avg_po_frequency / gm.max_frequency) * 25 +
            (pa.avg_months_purchased / 12) * 20 +
            COALESCE((1 - (pa.avg_price_cv / gm.max_cv)) * 15, 15) +
            (1 - (pa.avg_supplier_count / gm.max_supplier_count)) * 10,
        2) AS contract_priority_score
        
    FROM product_aggregate pa
    CROSS JOIN global_max gm
),

-- ============================================================
-- STEP 5: GROWTH QUALITY SIGNAL (Low Base Protection)
-- ============================================================
trend_analysis AS (
    SELECT
        sp.*,
        
        -- ============================================================
        -- GROWTH SIGNAL QUALITY
        -- If 2024 spend was <25% of average, growth may be from a low base
        -- ============================================================
        CASE 
            WHEN sp.spend_2024 < (sp.avg_annual_spend * 0.25) 
                 AND sp.yoy_growth_pct > 20 
            THEN '⚠️ Low Base Growth (Context Required)'
            WHEN sp.yoy_growth_pct > 20 THEN '✅ Organic Growth'
            WHEN sp.yoy_growth_pct BETWEEN 5 AND 20 THEN '📈 Moderate Growth'
            WHEN sp.yoy_growth_pct BETWEEN -5 AND 5 THEN '➡️ Stable'
            WHEN sp.yoy_growth_pct BETWEEN -20 AND -5 THEN '📉 Moderate Decline'
            WHEN sp.yoy_growth_pct < -20 THEN '📉 Strong Decline'
            ELSE '➡️ Stable'
        END AS growth_signal_quality,
        
        -- ============================================================
        -- PHASE-OUT OVERRIDE (Conflict Resolution)
        -- If demand collapsed (>50% decline AND 2025 spend <25% of 2023)
        -- ============================================================
        CASE 
            WHEN sp.yoy_growth_pct < -50 
                 AND sp.spend_2025 < (sp.spend_2023 * 0.25) 
            THEN '🔻 PHASE-OUT / DEMAND DECLINING'
            
            WHEN sp.contract_priority_score >= 70 THEN '🔴 Strong Contract Candidate'
            WHEN sp.contract_priority_score BETWEEN 40 AND 69 THEN '🟡 Strategic Review'
            ELSE '🟢 Maintain Flexible Purchasing'
        END AS final_recommendation,
        
        -- ============================================================
        -- CONTRACT TYPE RECOMMENDATION (Category-Based)
        -- ============================================================
        CASE 
            WHEN sp.product_name LIKE '%Consulting%' 
                 OR sp.product_name LIKE '%Advisory%' 
                 OR sp.product_name LIKE '%Audit%' 
                 OR sp.product_name LIKE '%Legal%' 
            THEN '📄 Rate Card / Statement of Work'
            
            WHEN sp.product_name LIKE '%Freight%' 
                 OR sp.product_name LIKE '%Shipping%' 
                 OR sp.product_name LIKE '%Cargo%' 
                 OR sp.product_name LIKE '%Logistics%' 
            THEN '📊 Index-Based Pricing Agreement'
            
            WHEN sp.product_name LIKE '%License%' 
                 OR sp.product_name LIKE '%Software%' 
                 OR sp.product_name LIKE '%Subscription%' 
                 OR sp.product_name LIKE '%Cloud%' 
                 OR sp.product_name LIKE '%Azure%' 
                 OR sp.product_name LIKE '%CRM%' 
                 OR sp.product_name LIKE '%Dynamics%' 
            THEN '💻 Enterprise License Agreement'
            
            WHEN sp.product_name LIKE '%Tire%' 
                 OR sp.product_name LIKE '%Truck%' 
                 OR sp.product_name LIKE '%Fleet%' 
            THEN '🔧 Volume Agreement (Tiered Pricing)'
            
            ELSE '📦 Annual Volume Contract'
        END AS contract_type_recommendation,
        
        -- ============================================================
        -- SAVINGS OPPORTUNITY (The CFO/CPO Headline)
        -- Estimated potential annual savings from contracting
        -- ============================================================
        ROUND(
            sp.avg_annual_spend * 
            (
                0.03 +  -- Base 3% negotiation leverage
                (CASE 
                    WHEN sp.avg_price_cv > 50 THEN 0.04   -- High volatility = more leverage
                    WHEN sp.avg_price_cv > 25 THEN 0.02
                    ELSE 0.01
                END) +
                (CASE 
                    WHEN sp.avg_supplier_count <= 2 THEN 0.02   -- Single/dual source = more leverage
                    ELSE 0.01
                END)
            ), 
        2) AS estimated_annual_savings_opportunity

    FROM scored_products sp
)

-- ============================================================
-- STEP 6: FINAL OUTPUT
-- ============================================================
SELECT 
    product_name,
    avg_annual_spend,
    spend_2023,
    spend_2024,
    spend_2025,
    ROUND(yoy_growth_pct, 2) AS yoy_growth_pct,
    growth_signal_quality,
    avg_po_frequency,
    po_frequency_2025,
    avg_months_purchased,
    avg_price_cv AS price_volatility_cv_pct,
    avg_supplier_count,
    
    -- Individual scores
    spend_score,
    frequency_score,
    consistency_score,
    volatility_score,
    concentration_score,
    contract_priority_score,
    
    -- Final recommendation (with phase-out override)
    final_recommendation,
    
    -- Contract type
    contract_type_recommendation,
    
    -- ============================================================
    -- SAVINGS OPPORTUNITY (The new Hero Metric)
    -- ============================================================
    estimated_annual_savings_opportunity,
    
    -- ============================================================
    -- EXECUTIVE INSIGHT (Context-Aware)
    -- ============================================================
    CASE 
        WHEN final_recommendation LIKE '%PHASE-OUT%' THEN 
            CONCAT('🔻 DEMAND COLLAPSED: ', ROUND(yoy_growth_pct, 1), '% YoY - Do not contract')
        
        WHEN final_recommendation LIKE '%Strong Contract%' 
             AND yoy_growth_pct > 20 
             AND growth_signal_quality LIKE '%Organic%' THEN 
            CONCAT('🚀 Top Priority: $', ROUND(avg_annual_spend/1000000, 1), 'M with ', ROUND(yoy_growth_pct, 0), '% organic growth')
        
        WHEN final_recommendation LIKE '%Strong Contract%' 
             AND avg_price_cv > 50 THEN 
            CONCAT('📈 High volatility (CV=', ROUND(avg_price_cv, 0), '%) - Lock in pricing')
        
        WHEN avg_supplier_count <= 2 AND avg_annual_spend > 1000000 THEN 
            CONCAT('⚠️ Single/Dual source ($', ROUND(avg_annual_spend/1000000, 1), 'M) - Secure supply')
        
        WHEN growth_signal_quality LIKE '%Low Base%' THEN 
            CONCAT('📊 ', ROUND(yoy_growth_pct, 0), '% growth from low base - Validate before contracting')
        
        ELSE 
            CONCAT(
                CASE 
                    WHEN final_recommendation LIKE '%Strategic Review%' THEN 'Score '
                    WHEN final_recommendation LIKE '%Maintain%' THEN 'On-demand: '
                    ELSE ''
                END,
                contract_priority_score, '/100'
            )
    END AS executive_insight

FROM trend_analysis

-- ============================================================
-- ORDER BY: High score + Savings Opportunity (double sort)
-- ============================================================
ORDER BY 
    CASE WHEN final_recommendation LIKE '%PHASE-OUT%' THEN 999 ELSE contract_priority_score END,
    estimated_annual_savings_opportunity DESC;
