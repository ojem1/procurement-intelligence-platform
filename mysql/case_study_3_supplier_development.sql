-- ============================================================
-- PROJECT 3: SUPPLIER PORTFOLIO OPTIMIZATION ENGINE
-- FINAL PRODUCTION VERSION
-- 
-- FEATURES:
--   - Balanced Strategic Position (20 pts)
--   - Concentration is a WARNING (not a score reward)
--   - Honest savings methodology (tier-based)
--   - Nuanced Recommended Actions
--   - Single supplier_score calculation
-- ============================================================

WITH 
-- ============================================================
-- STEP 1A: INVOICE-LEVEL METRICS
-- ============================================================
invoice_metrics AS (
    SELECT
        i.vendor_id,
        i.invoice_id,
        i.total AS invoice_total,
        i.invoice_date,
        i.validation_status,
        i.status,
        i.payment_status,
        i.approved_at,
        DATEDIFF(i.approved_at, i.invoice_date) AS approval_days,
        YEAR(i.invoice_date) AS invoice_year
    FROM invoice_july_2026 i
    WHERE i.currency = 'USD'
),

-- ============================================================
-- STEP 1B: PRODUCT-LEVEL METRICS
-- ============================================================
product_metrics AS (
    SELECT DISTINCT
        i.vendor_id,
        il.description AS product_name
    FROM invoice_line_items_july_2026 il
    JOIN invoice_july_2026 i ON il.invoice_id = i.invoice_id
    WHERE i.currency = 'USD'
),

-- ============================================================
-- STEP 1C: AGGREGATE VENDOR METRICS
-- ============================================================
vendor_aggregates AS (
    SELECT
        v.vendor_id,
        v.vendor_name,
        
        -- BUSINESS IMPORTANCE
        ROUND(SUM(im.invoice_total), 2) AS total_spend,
        COUNT(DISTINCT im.invoice_id) AS invoice_count,
        COUNT(DISTINCT im.invoice_year) AS years_active,
        
        -- OPERATIONAL QUALITY
        COUNT(DISTINCT CASE WHEN im.validation_status = 'Rejected' THEN im.invoice_id END) AS rejected_invoices,
        COUNT(DISTINCT CASE WHEN im.payment_status = 'Paid' THEN im.invoice_id END) AS paid_invoices,
        
        -- INTERNAL PROCESSING
        AVG(im.approval_days) AS avg_approval_days,
        
        -- YoY GROWTH
        SUM(CASE WHEN im.invoice_year = 2025 THEN im.invoice_total ELSE 0 END) AS spend_2025,
        SUM(CASE WHEN im.invoice_year = 2024 THEN im.invoice_total ELSE 0 END) AS spend_2024
        
    FROM vendors_july_2026 v
    JOIN invoice_metrics im ON v.vendor_id = im.vendor_id
    WHERE v.currency = 'USD'
    GROUP BY v.vendor_id, v.vendor_name
),

-- ============================================================
-- STEP 1D: PRODUCT COUNT PER VENDOR
-- ============================================================
vendor_products AS (
    SELECT
        vendor_id,
        COUNT(DISTINCT product_name) AS unique_products
    FROM product_metrics
    GROUP BY vendor_id
),

-- ============================================================
-- STEP 2: COMBINE METRICS
-- ============================================================
vendor_complete AS (
    SELECT
        va.vendor_id,
        va.vendor_name,
        va.total_spend,
        va.invoice_count,
        COALESCE(vp.unique_products, 0) AS unique_products,
        va.years_active,
        va.rejected_invoices,
        va.paid_invoices,
        va.avg_approval_days,
        va.spend_2025,
        va.spend_2024
    FROM vendor_aggregates va
    LEFT JOIN vendor_products vp ON va.vendor_id = vp.vendor_id
),

-- ============================================================
-- STEP 3: CALCULATE RATES
-- ============================================================
supplier_rates AS (
    SELECT
        vendor_id,
        vendor_name,
        total_spend,
        invoice_count,
        unique_products,
        years_active,
        rejected_invoices,
        paid_invoices,
        avg_approval_days,
        spend_2025,
        spend_2024,
        
        -- INVOICE ACCURACY
        LEAST(ROUND(100.0 * (invoice_count - rejected_invoices) / NULLIF(invoice_count, 0), 2), 100) AS invoice_accuracy_pct,
        
        -- REJECTION RATE
        LEAST(ROUND(100.0 * rejected_invoices / NULLIF(invoice_count, 0), 2), 100) AS rejection_rate_pct,
        
        -- PAYMENT COMPLETION (Internal AP metric)
        LEAST(ROUND(100.0 * paid_invoices / NULLIF(invoice_count, 0), 2), 100) AS payment_completion_pct,
        
        -- YoY GROWTH (Capped at 200%)
        CASE
            WHEN spend_2024 = 0 THEN NULL
            WHEN (spend_2025 - spend_2024) / NULLIF(spend_2024, 0) * 100 > 200 THEN 200
            WHEN (spend_2025 - spend_2024) / NULLIF(spend_2024, 0) * 100 < -100 THEN -100
            ELSE ROUND((spend_2025 - spend_2024) / NULLIF(spend_2024, 0) * 100, 2)
        END AS yoy_growth_pct,
        
        -- GROWTH CONTEXT
        CASE
            WHEN spend_2024 = 0 THEN 'New in 2025'
            WHEN (spend_2025 - spend_2024) / NULLIF(spend_2024, 0) * 100 > 200 THEN '>200% Growth'
            WHEN (spend_2025 - spend_2024) / NULLIF(spend_2024, 0) * 100 < -100 THEN '-100% Decline'
            ELSE 'Normal'
        END AS growth_context
        
    FROM vendor_complete
),

-- ============================================================
-- STEP 4: CALCULATE DIMENSION SCORES
-- ============================================================
dimension_scores AS (
    SELECT
        sr.*,
        
        -- ============================================================
        -- DIMENSION 1: BUSINESS IMPORTANCE (20 pts)
        -- ============================================================
        -- Spend (max 8)
        CASE 
            WHEN sr.total_spend >= 20000000 THEN 8
            WHEN sr.total_spend >= 10000000 THEN 6
            WHEN sr.total_spend >= 5000000 THEN 4
            WHEN sr.total_spend >= 2000000 THEN 2
            ELSE 0
        END +
        -- Categories (max 6)
        CASE 
            WHEN sr.unique_products >= 4 THEN 6
            WHEN sr.unique_products >= 3 THEN 4.5
            WHEN sr.unique_products >= 2 THEN 3
            WHEN sr.unique_products >= 1 THEN 1.5
            ELSE 0
        END +
        -- Years Active (max 6)
        CASE 
            WHEN sr.years_active >= 3 THEN 6
            WHEN sr.years_active >= 2 THEN 4
            WHEN sr.years_active >= 1 THEN 2
            ELSE 0
        END AS business_importance_score,
        
        -- ============================================================
        -- DIMENSION 2: OPERATIONAL QUALITY (30 pts)
        -- ============================================================
        -- Invoice Accuracy (max 15 pts)
        CASE 
            WHEN sr.invoice_accuracy_pct >= 98 THEN 15
            WHEN sr.invoice_accuracy_pct >= 95 THEN 13
            WHEN sr.invoice_accuracy_pct >= 90 THEN 10.5
            WHEN sr.invoice_accuracy_pct >= 85 THEN 8
            WHEN sr.invoice_accuracy_pct >= 80 THEN 5
            ELSE 0
        END +
        -- Payment Completion (max 15 pts)
        CASE 
            WHEN sr.payment_completion_pct >= 95 THEN 15
            WHEN sr.payment_completion_pct >= 90 THEN 13
            WHEN sr.payment_completion_pct >= 85 THEN 10.5
            WHEN sr.payment_completion_pct >= 80 THEN 8
            WHEN sr.payment_completion_pct >= 70 THEN 5
            ELSE 0
        END AS operational_quality_score,
        
        -- ============================================================
        -- DIMENSION 3: INTERNAL PROCESSING EFFICIENCY (20 pts)
        -- ============================================================
        CASE 
            WHEN sr.avg_approval_days <= 3 THEN 20
            WHEN sr.avg_approval_days <= 5 THEN 15
            WHEN sr.avg_approval_days <= 8 THEN 10
            WHEN sr.avg_approval_days <= 12 THEN 5
            ELSE 0
        END AS processing_efficiency_score,
        
        -- ============================================================
        -- DIMENSION 4: STRATEGIC POSITION (20 pts)
        -- BALANCED: Rewards sustained excellence, not just growth
        -- ============================================================
        -- Critical Supplier (6 pts): High spend + High quality + Longevity
        CASE 
            WHEN sr.total_spend >= 5000000 
                 AND sr.invoice_accuracy_pct >= 95 
                 AND sr.years_active >= 3 
            THEN 6
            WHEN sr.total_spend >= 5000000 
                 AND sr.invoice_accuracy_pct >= 95 
                 AND sr.years_active >= 2 
            THEN 4
            ELSE 0
        END +
        -- Relationship Longevity (5 pts): Rewards sustained partnerships
        CASE 
            WHEN sr.years_active >= 5 THEN 5
            WHEN sr.years_active >= 3 THEN 3
            WHEN sr.years_active >= 2 THEN 1
            ELSE 0
        END +
        -- Performance Leadership (5 pts): Excellence + Growth + Longevity
        CASE 
            WHEN sr.invoice_accuracy_pct >= 98 
                 AND sr.yoy_growth_pct > 10 
                 AND sr.years_active >= 2 
            THEN 5
            WHEN sr.invoice_accuracy_pct >= 98 
                 AND sr.yoy_growth_pct > 5 
            THEN 3
            ELSE 0
        END +
        -- Growth Trend (4 pts): Positive momentum (reduced from 6 to 4)
        CASE 
            WHEN sr.yoy_growth_pct > 20 THEN 4
            WHEN sr.yoy_growth_pct BETWEEN 10 AND 20 THEN 3
            WHEN sr.yoy_growth_pct BETWEEN 5 AND 10 THEN 2
            ELSE 0
        END AS strategic_position_score,
        
        -- ============================================================
        -- DIMENSION 5: RISK (10 pts)
        -- ============================================================
        CASE 
            WHEN sr.rejection_rate_pct = 0 THEN 10
            WHEN sr.rejection_rate_pct <= 2 THEN 9
            WHEN sr.rejection_rate_pct <= 5 THEN 7
            WHEN sr.rejection_rate_pct <= 10 THEN 4
            ELSE 0
        END AS risk_score
        
    FROM supplier_rates sr
),

-- ============================================================
-- STEP 5: CALCULATE TOTAL SCORE & RECOMMENDED ACTION
-- ============================================================
supplier_scores AS (
    SELECT
        ds.*,
        ROUND(
            ds.business_importance_score +
            ds.operational_quality_score +
            ds.processing_efficiency_score +
            ds.strategic_position_score +
            ds.risk_score,
        2) AS supplier_score,
        
        -- ============================================================
        -- RECOMMENDED ACTION (Nuanced)
        -- ============================================================
        CASE 
            -- STRATEGIC: Expand
            WHEN ROUND(
                ds.business_importance_score +
                ds.operational_quality_score +
                ds.processing_efficiency_score +
                ds.strategic_position_score +
                ds.risk_score,
            2) >= 85 AND ds.invoice_accuracy_pct >= 98 
            THEN 'Expand Relationship'
            
            -- PREFERRED + CONCENTRATION: Maintain + Develop Backup
            WHEN ROUND(
                ds.business_importance_score +
                ds.operational_quality_score +
                ds.processing_efficiency_score +
                ds.strategic_position_score +
                ds.risk_score,
            2) >= 70 
                 AND ds.unique_products <= 2 
                 AND ds.total_spend > 5000000 
            THEN 'Maintain + Develop Backup Supplier'
            
            -- PREFERRED + HIGH SPEND: Renegotiate
            WHEN ROUND(
                ds.business_importance_score +
                ds.operational_quality_score +
                ds.processing_efficiency_score +
                ds.strategic_position_score +
                ds.risk_score,
            2) >= 70 
                 AND ds.total_spend > 10000000 
                 AND ds.invoice_accuracy_pct >= 95 
            THEN 'Renegotiate Contract'
            
            -- PREFERRED: Maintain
            WHEN ROUND(
                ds.business_importance_score +
                ds.operational_quality_score +
                ds.processing_efficiency_score +
                ds.strategic_position_score +
                ds.risk_score,
            2) >= 70 
            THEN 'Maintain'
            
            -- APPROVED + DECLINING: Performance Improvement
            WHEN ROUND(
                ds.business_importance_score +
                ds.operational_quality_score +
                ds.processing_efficiency_score +
                ds.strategic_position_score +
                ds.risk_score,
            2) BETWEEN 50 AND 69 
                 AND (ds.invoice_accuracy_pct < 90 OR ds.rejection_rate_pct > 10)
            THEN 'Performance Improvement Plan'
            
            -- APPROVED: Review & Improve
            WHEN ROUND(
                ds.business_importance_score +
                ds.operational_quality_score +
                ds.processing_efficiency_score +
                ds.strategic_position_score +
                ds.risk_score,
            2) BETWEEN 50 AND 69 
            THEN 'Review & Improve'
            
            -- MONITOR: Reduce Dependency
            WHEN ROUND(
                ds.business_importance_score +
                ds.operational_quality_score +
                ds.processing_efficiency_score +
                ds.strategic_position_score +
                ds.risk_score,
            2) < 50 
            THEN 'Reduce Dependency'
            
            ELSE 'Standard Review'
        END AS recommended_action
        
    FROM dimension_scores ds
)

-- ============================================================
-- STEP 6: FINAL OUTPUT
-- ============================================================
SELECT 
    vendor_name,
    total_spend,
    invoice_count,
    unique_products AS product_categories,
    years_active,
    invoice_accuracy_pct,
    ROUND(avg_approval_days, 1) AS avg_internal_approval_days,
    ROUND(rejection_rate_pct, 1) AS rejection_rate_pct,
    ROUND(payment_completion_pct, 1) AS payment_completion_pct,
    
    -- Growth
    CASE 
        WHEN growth_context = '>200% Growth' THEN '>200%'
        WHEN growth_context = '-100% Decline' THEN '-100%'
        ELSE ROUND(yoy_growth_pct, 1)
    END AS yoy_growth_pct,
    growth_context,
    
    -- Dimension scores
    business_importance_score,
    operational_quality_score,
    processing_efficiency_score,
    strategic_position_score,
    risk_score,
    
    -- TOTAL SCORE
    supplier_score,
    
    -- ============================================================
    -- SUPPLIER TIER
    -- ============================================================
    CASE 
        WHEN supplier_score >= 85 THEN '⭐ Strategic Partner'
        WHEN supplier_score >= 70 THEN '🟢 Preferred Supplier'
        WHEN supplier_score >= 50 THEN '🟡 Approved Supplier'
        ELSE '🔴 Monitor / Demote'
    END AS supplier_tier,
    
    -- ============================================================
    -- RECOMMENDED ACTION
    -- ============================================================
    recommended_action,
    
    -- ============================================================
    -- STRATEGIC INTELLIGENCE FLAGS
    -- ============================================================
    CASE
        -- Strategic Partner
        WHEN supplier_score >= 85 AND invoice_accuracy_pct >= 98 AND years_active >= 2
        THEN '⭐ Strategic Partner - Expand Relationship'
        
        -- Consolidation Opportunity
        WHEN total_spend < 5000000 AND invoice_accuracy_pct >= 98 AND avg_approval_days <= 5
        THEN '📈 Consolidation Opportunity'
        
        -- High Friction
        WHEN total_spend > 10000000 AND invoice_accuracy_pct < 90
        THEN '⚠️ High Friction - Executive Review'
        
        -- Performance Declining
        WHEN invoice_accuracy_pct < 90 AND rejection_rate_pct > 10 AND years_active >= 2
        THEN '🔻 Performance Declining - Corrective Action'
        
        -- Supplier Concentration (WARNING ONLY)
        WHEN unique_products <= 2 AND total_spend > 5000000
        THEN '🚨 Supplier Concentration - Develop Backup Supplier'
        
        -- Renegotiate Opportunity
        WHEN total_spend > 5000000 AND invoice_accuracy_pct >= 98 AND yoy_growth_pct > 10
        THEN '💰 Renegotiate Opportunity - Seek Better Terms'
        
        ELSE '📋 Standard Review'
    END AS strategic_flag,
    
    -- ============================================================
    -- SPEND MIGRATION OPPORTUNITY
    -- ============================================================
    CASE 
        WHEN supplier_score >= 85 AND invoice_accuracy_pct >= 98 THEN 'High (15-25%)'
        WHEN total_spend < 5000000 AND invoice_accuracy_pct >= 98 AND avg_approval_days <= 5 THEN 'Medium (10-20%)'
        WHEN total_spend > 10000000 AND invoice_accuracy_pct < 90 THEN 'High (15-25%)'
        WHEN invoice_accuracy_pct < 90 AND rejection_rate_pct > 10 THEN 'Medium (10-20%)'
        ELSE 'Low (0-5%)'
    END AS spend_migration_opportunity,

    -- ============================================================
    -- MIGRATION DIRECTION
    -- ============================================================
    CASE 
        WHEN supplier_score >= 85 AND invoice_accuracy_pct >= 98 THEN 'Increase'
        WHEN total_spend < 5000000 AND invoice_accuracy_pct >= 98 THEN 'Increase'
        WHEN total_spend > 10000000 AND invoice_accuracy_pct < 90 THEN 'Decrease'
        WHEN invoice_accuracy_pct < 90 AND rejection_rate_pct > 10 THEN 'Decrease'
        WHEN unique_products <= 2 AND total_spend > 5000000 THEN 'Maintain (with alternatives)'
        ELSE 'Maintain'
    END AS migration_direction,
    
    -- ============================================================
    -- ESTIMATED ANNUAL SAVINGS (Tier-based, transparent)
    -- ============================================================
    ROUND(
        CASE 
            -- Strategic Partner: 3-5%
            WHEN supplier_score >= 85 AND total_spend > 5000000 
                THEN total_spend * 0.04
            -- Preferred Supplier: 2-4%
            WHEN supplier_score >= 70 AND total_spend > 5000000 
                THEN total_spend * 0.03
            -- Approved Supplier: 1-2%
            WHEN supplier_score >= 50 AND total_spend > 5000000 
                THEN total_spend * 0.015
            -- Monitor: Cost avoidance 8-12%
            WHEN supplier_score < 50 AND total_spend > 5000000 
                THEN total_spend * 0.10
            -- Consolidation: 3-5%
            WHEN total_spend < 5000000 AND invoice_accuracy_pct >= 98 
                THEN total_spend * 0.04
            ELSE 0
        END,
    2) AS estimated_annual_savings,
    
    -- ============================================================
    -- SAVINGS OPPORTUNITY BAND (Transparent)
    -- ============================================================
    CASE 
        WHEN supplier_score >= 85 AND total_spend > 5000000 THEN '3-5%'
        WHEN supplier_score >= 70 AND total_spend > 5000000 THEN '2-4%'
        WHEN supplier_score >= 50 AND total_spend > 5000000 THEN '1-2%'
        WHEN supplier_score < 50 AND total_spend > 5000000 THEN '8-12% (cost avoidance)'
        WHEN total_spend < 5000000 AND invoice_accuracy_pct >= 98 THEN '3-5%'
        ELSE '0-1%'
    END AS savings_opportunity_band,
    
    -- ============================================================
    -- EXECUTIVE INSIGHT
    -- ============================================================
    CASE 
        WHEN supplier_score >= 85 AND invoice_accuracy_pct >= 98 AND years_active >= 2
        THEN CONCAT('⭐ STRATEGIC: $', ROUND(total_spend/1000000, 1), 'M, ', 
                   invoice_accuracy_pct, '% accuracy, ', years_active, ' yrs - Expand relationship')
        
        WHEN total_spend < 5000000 AND invoice_accuracy_pct >= 98 AND avg_approval_days <= 5
        THEN CONCAT('📈 CONSOLIDATE: $', ROUND(total_spend/1000000, 1), 'M at ', 
                   invoice_accuracy_pct, '% - Move more spend here')
        
        WHEN total_spend > 10000000 AND invoice_accuracy_pct < 90
        THEN CONCAT('⚠️ EXECUTIVE REVIEW: $', ROUND(total_spend/1000000, 1), 'M, ', 
                   ROUND(rejection_rate_pct, 0), '% rejections - Immediate action required')
        
        WHEN invoice_accuracy_pct < 90 AND rejection_rate_pct > 10
        THEN CONCAT('🔻 PERFORMANCE DECLINING: ', ROUND(rejection_rate_pct, 0), '% rejections - PIP required')
        
        WHEN unique_products <= 2 AND total_spend > 5000000
        THEN CONCAT('🚨 CONCENTRATION: $', ROUND(total_spend/1000000, 1), 'M single product - Develop backup supplier')
        
        WHEN total_spend > 5000000 AND invoice_accuracy_pct >= 98 AND yoy_growth_pct > 10
        THEN CONCAT('💰 RENEGOTIATE: $', ROUND(total_spend/1000000, 1), 'M - Seek better terms')
        
        ELSE CONCAT(recommended_action, ' - Score ', supplier_score, '/100')
    END AS executive_insight

FROM supplier_scores

-- ============================================================
-- ORDER BY: Score descending
-- ============================================================
ORDER BY supplier_score DESC;
