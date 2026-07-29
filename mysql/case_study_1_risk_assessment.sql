/*
# Vendor Spend Exposure & Risk Analysis

This SQL query analyzes **financial dependency, invoice error rates, and vendor risk scores** to:
- **Identify high-risk vendors** with financial exposure (e.g., top spenders with validation failures).
- **Calculate a weighted risk score** (Spend: 30%, Error Rate: 30%, Rejection Rate: 20%, Risk Level: 20%).
- **Flag vendors for action**: 🔴 **REPLACE** (Score ≥70), 🟡 **MONITOR** (40–69), or 🟢 **RETAIN** (Score <40).
- **Highlight "Hero Findings"** (e.g., top spenders with hidden risks).

**Key Outputs**:
- Vendor risk scores (0–100).
- Procurement recommendations (Replace/Monitor/Retain).
- Executive insights (e.g., "Highest spend vendor ($XM) - Monitor closely").

Use this to **prioritize vendor management** and mitigate financial risks.
-- Vendor Spend Exposure
-- ---Identify where the company has financial dependency
-- Invoice Error Rate
-- Vendor Risk Score
-- ----Create a scoring model: Calculates error rates, validation failures, rejected payments.
-- 	Applies business rules to flag Retain/Monitor/Replace.
-- Identifies the "Hero Finding" (e.g., top spender is a ticking bomb).
*/

WITH cte_vendor_metrics AS (
    SELECT
        v.vendor_id,
        v.vendor_name,
        v.risk_level,
        SUM(i.total) AS total_spend,
        COUNT(i.invoice_id) AS invoice_count,
        
        -- Invoice Error Rate
        SUM(CASE WHEN i.validation_status = 'Rejected' THEN 1 ELSE 0 END) AS failed_validations,
        SUM(CASE WHEN i.status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_payments,
        
        -- Calculate Percentage Rates
        ROUND(100.0 * SUM(CASE WHEN i.validation_status = 'Rejected' THEN 1 ELSE 0 END) / NULLIF(COUNT(i.invoice_id), 0), 2) AS error_rate_pct,
        ROUND(100.0 * SUM(CASE WHEN i.status = 'Rejected' THEN 1 ELSE 0 END) / NULLIF(COUNT(i.invoice_id), 0), 2) AS rejection_rate_pct
        
    FROM vendors_july_2026 v
    JOIN invoice_july_2026 i ON v.vendor_id = i.vendor_id
    WHERE v.currency = 'USD'
    GROUP BY v.vendor_id, v.vendor_name, v.risk_level
),
-- Step 4: Weighted Vendor Risk Score (30/30/20/20)
scored_vendors AS (
    SELECT
        vendor_name,
        total_spend,
        invoice_count,
        risk_level,
        error_rate_pct,
        rejection_rate_pct,
        
        -- Spend Score (30 pts) - Higher spend = higher score (max 30)
        ROUND((total_spend / (SELECT MAX(total_spend) FROM cte_vendor_metrics)) * 30, 2) AS spend_score,
        
        -- Error Score (30 pts) - Higher errors = higher score (max 30)
        -- Cap at 30 for anything > 30% error rate
        CASE 
            WHEN error_rate_pct >= 30 THEN 30
            ELSE ROUND((error_rate_pct / 30) * 30, 2) 
        END AS error_score,
        
        -- Rejection Score (20 pts) - Higher rejections = higher score (max 20)
        CASE 
            WHEN rejection_rate_pct >= 30 THEN 20
            ELSE ROUND((rejection_rate_pct / 30) * 20, 2) 
        END AS rejection_score,
        
        -- Risk Level Score (20 pts) - High=20, Medium=10, Low=0
        CASE risk_level
            WHEN 'High' THEN 20
            WHEN 'Medium' THEN 10
            WHEN 'Low' THEN 0
            ELSE 0
        END AS risk_score

    FROM cte_vendor_metrics
)

-- Step 5: Final Decision & Executive Insights
SELECT 
    vendor_name,
    total_spend,
    invoice_count,
    risk_level,
    error_rate_pct,
    rejection_rate_pct,
    
    -- Calculate Total Score (out of 100)
    ROUND((spend_score + error_score + rejection_score + risk_score),2) AS vendor_risk_score,
    
    -- Decision Rule (based on total score)
    CASE 
        WHEN (spend_score + error_score + rejection_score + risk_score) >= 70 THEN '🔴 REPLACE - Phase Out in 6 Months'
        WHEN (spend_score + error_score + rejection_score + risk_score) BETWEEN 40 AND 69 THEN '🟡 MONITOR - Quarterly Review Required'
        ELSE '🟢 RETAIN - Strategic Partner'
    END AS procurement_recommendation,
    
    -- Step 6: The "Hero Finding" - Narrative driver (FIXED for MySQL)
    CASE 
        WHEN (spend_score + error_score + rejection_score + risk_score) >= 70 THEN 
            CONCAT('Score ', (spend_score + error_score + rejection_score + risk_score), '/100 - Prioritize replacement')
        WHEN total_spend = (SELECT MAX(total_spend) FROM cte_vendor_metrics) THEN 
            CONCAT('⭐ HERO FINDING: Highest spend vendor ($', ROUND(total_spend/1000000, 1), 'M) - Monitor closely')
        ELSE 
            CONCAT('Score ', (spend_score + error_score + rejection_score + risk_score), '/100 - Standard oversight')
    END AS executive_insight

FROM scored_vendors
ORDER BY 
    -- Sort by highest risk score first (the biggest problems)
    (spend_score + error_score + rejection_score + risk_score) DESC;
