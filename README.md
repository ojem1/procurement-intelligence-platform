# Enterprise Procurement Intelligence Platform
**SQL • Tableau • Procurement Analytics • Business Intelligence • KPI Design • Decision Modeling**

![SQL](https://img.shields.io/badge/SQL-MySQL-blue)
![Tableau](https://img.shields.io/badge/Tableau-Data%20Visualization-orange)
![Procurement Analytics](https://img.shields.io/badge/Procurement%20Analytics-Business%20Intelligence-green)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

![Hero Dashboard Image](docs/images/dashboard-2.png)

---
Most procurement dashboards explain what happened. This platform **recommends what procurement should do next** by combining **ERP data, SQL decision models, and Tableau executive dashboards**.

---

## 🎯 Executive Impact
   Metric                     | **Value**          |
 |----------------------------|---------------------|
 | Spend Analyzed             | **$626.9M**        |
 | Suppliers Analyzed         | **88**             |
 | Invoices Analyzed          | **2,168**          |
 | Products Analyzed          | **126**            |
 | Modeled Value Opportunity   | **$4.0M+**         |

---
## 🧠 Decision Engines
 | **Engine**               | **Business Question**               | **Recommendation**               |
 |--------------------------|-------------------------------------|----------------------------------|
 | Supplier Risk            | Which suppliers create operational risk? | Retain / Monitor / Replace       |
 | Contract Intelligence    | Which products deserve contracts?   | Contract / Review / Phase-Out    |
 | Supplier Development     | Which suppliers deserve more business? | Strategic / Preferred / Approved |

---
## 🖼️ Dashboard Gallery
 | **Risk** | **Contract** | **Development** |
 |----------|--------------|-----------------|
 | ![Supplier Risk Dashboard](docs/images/CS1_1_chart_rscatterplot.png) | ![Contract Intelligence Dashboard](docs/images/CS2_1_contract_scatter.png) | ![Supplier Development Dashboard](docs/images/CS3_1_supplier_quadrant.png) |

---
## 📈 Business Value
 | **Capability**               | **Business Outcome**                          |
 |------------------------------|-----------------------------------------------|
 | Supplier Risk Prioritization | Identify vendors requiring intervention       |
 | Contract Intelligence        | Recommend products for negotiation or phase-out|
 | Supplier Segmentation        | Improve sourcing strategy                     |
 | KPI Reporting                 | Executive visibility into spend and risk      |
 | Decision Scorecards          | Actionable recommendations (Retain/Monitor/Replace) |
 | Portfolio Optimization       | Reduce concentration risk and improve diversity |

---
## 🎯 Business Problem
Procurement teams often rely on **historical reports** rather than **actionable insights**. This platform bridges the gap by:
- Identifying **high-risk suppliers** before they disrupt operations.
- Highlighting **contract opportunities** tied to demand trends.
- Segmenting suppliers to **optimize relationships and mitigate risks**.

---
## ✨ Solution
Enterprise Procurement Intelligence Platform combines **SQL, business rules, and Tableau dashboards** to:
- Score suppliers based on **spend, error rates, and risk levels**.
- Flag **contract candidates** and **phase-out risks**.
- Deliver **executive-ready visualizations** for data-driven decisions.

---
## 🏗️ Architecture
![Architecture Diagram](docs/images/architecture.png)

---
## 💡 Highlights
✅ Built a **weighted supplier risk scoring model** to prioritize actions.
✅ Identified **$174.8M in suppliers requiring monitoring**.
✅ Prevented **incorrect contracting decisions** using demand trend analysis.
✅ Estimated **$4.0M+ annual value opportunities**.

---
## 🔍 SQL Preview
```sql
-- Supplier Risk Score (Spend 30% + Errors 30% + Rejections 20% + Risk 20%)
WITH cte_vendor_metrics AS (
    SELECT
        v.vendor_id,
        v.vendor_name,
        SUM(i.total) AS total_spend,
        ROUND(100.0 * SUM(CASE WHEN i.validation_status = 'Rejected' THEN 1 ELSE 0 END)
        / COUNT(i.invoice_id), 2) AS error_rate_pct
    FROM vendors_july_2026 v
    JOIN invoice_july_2026 i ON v.vendor_id = i.vendor_id
    GROUP BY v.vendor_id, v.vendor_name
)
SELECT
    vendor_name,
    total_spend,
    ROUND((total_spend / max_spend) * 30 + (error_rate_pct / 30) * 30, 2) AS vendor_risk_score
FROM cte_vendor_metrics;
Full SQL scripts available in the mysql/ directory.
```
