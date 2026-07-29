# Enterprise Procurement Intelligence Platform
**SQL • Tableau • Executive Analytics • Decision Intelligence**

![Hero Dashboard Image](docs/images/dashboard_hero.png)

---

## 📌 Repository Overview
This repository contains:
- **SQL data models** (3 decision engines, 25+ CTEs)
- **Tableau dashboards** (3 interactive visualizations)
- **Executive reporting** (PDFs with methodology and insights)
- **Business scoring models** (risk, contract, supplier)
- **Synthetic ERP dataset** (88 suppliers, 2,168 invoices, $626.9M spend)

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
## 📊 Business Impact
   Metric                     | Value          |
 |----------------------------|----------------|
 | Spend Analyzed             | $626.9M        |
 | Suppliers Analyzed         | 88             |
 | Invoices Analyzed          | 2,168          |
 | Estimated Opportunities    | **$4.0M+**     |
 | Products Analyzed          | 126            |

---
## 💡 Highlights
- Identified **18 suppliers requiring monitoring** ($174.8M in annual spend).
- Built a **weighted supplier risk model** using operational and financial indicators.
- Prevented incorrect contract recommendations with a **demand trend override**.
- Uncovered **$4.0M+ in annual value opportunities**.

---
## 🏗️ Architecture
![Architecture Diagram](docs/images/architecture.png)

---
## 🖼️ Dashboard Gallery
### Supplier Risk Dashboard
![Supplier Risk Dashboard](docs/images/dashboard_risk.png)
### Contract Intelligence Dashboard
![Contract Intelligence Dashboard](docs/images/dashboard_contract.png)
### Supplier Development Dashboard
![Supplier Development Dashboard](docs/images/dashboard_supplier.png)

---
## 🔍 SQL Logic Preview
```sql
-- Supplier Risk Score (Spend 30% + Errors 30% + Rejections 20% + Risk 20%)
WITH cte_vendor_metrics AS (
    SELECT
        v.vendor_id,
        v.vendor_name,
        SUM(i.total) AS total_spend,
        ROUND(100.0 * SUM(CASE WHEN i.validation_status = 'Rejected' THEN 1 ELSE 0 END) / COUNT(i.invoice_id), 2) AS error_rate_pct
    FROM vendors_july_2026 v
    JOIN invoice_july_2026 i ON v.vendor_id = i.vendor_id
    GROUP BY v.vendor_id, v.vendor_name
)
SELECT
    vendor_name,
    total_spend,
    ROUND((total_spend / max_spend) * 30 + (error_rate_pct / 30) * 30, 2) AS vendor_risk_score,
    CASE
        WHEN vendor_risk_score >= 70 THEN '🔴 Replace'
        WHEN vendor_risk_score >= 40 THEN '🟡 Monitor'
        ELSE '🟢 Retain'
    END AS recommendation
FROM cte_vendor_metrics;

Full SQL scripts available in the mysql/ directory.

📁 Repository Structure
.
├── mysql/
│   ├── risk_engine.sql
│   ├── contract_engine.sql
│   └── supplier_engine.sql
├── tableau/
│   └── ProcurementDashboard.twbx
├── docs/
│   ├── ExecutiveSummary.pdf
│   ├── FullReport.pdf
│   └── images/
└── README.md

🛠️ Technology Stack

Data Extraction & Transformation: SQL (MySQL)
Decision Scoring Models: SQL (Common Table Expressions)
Data Visualization: Tableau
Version Control: Git / GitHub

🎯 Why I Built This
Most procurement dashboards report historical KPIs. This project demonstrates how SQL, business rules, and visualization can be combined into a decision-support platform that recommends actions rather than simply reporting metrics. The goal was to simulate how an enterprise procurement analytics team might design an executive intelligence platform using synthetic ERP data.

👤 About the Author
I'm Oje Ebhota, a Senior Data & Analytics Consultant with 19+ years of enterprise technology experience.
Specialties:

Advanced SQL
Procurement Analytics
Tableau & Business Intelligence
AI Automation
ERP Analytics
LinkedIn | Portfolio

📜 License
This project is licensed under the MIT License – see the LICENSE file for details.
