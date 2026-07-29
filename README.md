# Enterprise Procurement Intelligence Platform

**An end-to-end analytics solution for procurement decision support**

---

## 📋 Executive Summary

This project delivers a unified analytics platform that helps procurement leaders answer three critical questions:

| Engine | Core Question | Output |
| :--- | :--- | :--- |
| **Risk Management** | Which suppliers create operational risk? | Retain / Monitor / Replace |
| **Contract Intelligence** | Which products should be under contract? | Contract / Review / Phase-Out |
| **Supplier Development** | Which suppliers deserve more business? | Strategic / Preferred / Approved / Monitor |

---

## 🎯 Key Outcomes

| Metric | Value |
| :--- | :--- |
| Total Spend Analyzed | $626.9M |
| Suppliers Analyzed | 88 |
| Invoices Analyzed | 2,168 |
| Vendors Flagged for Monitoring | 18 ($174.8M) |
| Contract Candidates | 1 (Power Tools, $198K savings) |
| Concentration Risk Exposure | 10 suppliers ($87.7M) |
| Illustrative Annual Savings | $4.0M+ |

---

## 🏗️ Platform Architecture
┌─────────────────────────────────────────────────────────────────┐
│ ERP SYSTEM │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│ │ Vendor │ │ Invoice │ │ Purchase Order │ │
│ │ Master │ │ Headers │ │ History │ │
│ └─────────────┘ └─────────────┘ └─────────────────────────┘ │
│ │ │ │ │
│ └────────────────┼────────────────────┘ │
│ ▼ │
│ ┌─────────────────────┐ │
│ │ SQL Views / CTEs │ │
│ │ (Clean, Aggregated)│ │
│ └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────────┐
│ ANALYTICS LAYER │
│ │
│ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ │
│ │ Risk Management │ │ Contract │ │ Supplier │ │
│ │ Engine │ │ Intelligence │ │ Development │ │
│ │ │ │ Engine │ │ Engine │ │
│ └─────────────────┘ └─────────────────┘ └─────────────────┘ │
│ │ │ │ │
│ ▼ ▼ ▼ │
│ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ │
│ │ Retain/Monitor/ │ │ Contract/Review/│ │ Strategic/ │ │
│ │ Replace │ │ Phase-Out │ │ Preferred/ │ │
│ │ │ │ │ │ Approved/Monitor│ │
│ └─────────────────┘ └─────────────────┘ └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────────┐
│ EXECUTIVE DASHBOARD │
│ │
│ ┌─────────────────────────────────────────────────────────────┐│
│ │ KPI Cards: 88 Suppliers | $627M Spend | $2.7M Savings ││
│ └─────────────────────────────────────────────────────────────┘│
│ ┌─────────────────────────┐ ┌─────────────────────────────┐ ││
│ │ Supplier Risk Matrix │ │ Contract Priority Scatter │ ││
│ └─────────────────────────┘ └─────────────────────────────┘ ││
└─────────────────────────────────────────────────────────────────┘
│
▼
┌─────────────────────────────────────────────────────────────────┐
│ PROCUREMENT DECISIONS │
│ │
│ ✅ Expand relationship with Vintage Store │
│ ✅ Negotiate Power Tools contract │
│ ✅ Develop backup suppliers for 10 concentration-risk vendors │
└─────────────────────────────────────────────────────────────────┘

---

## 🛠️ Technology Stack

| Component | Technology |
| :--- | :--- |
| **Data Extraction & Transformation** | SQL (MySQL) |
| **Decision Scoring Models** | SQL (Common Table Expressions) |
| **Data Visualization** | Tableau Desktop / Tableau Public |
| **Data Exploration** | Microsoft Excel |
| **Documentation** | Markdown / PDF |
| **Version Control** | Git / GitHub |

---

## 📊 Dashboard Previews

### Supplier Risk Dashboard

![Supplier Risk Dashboard](docs/images/dashboard_risk.png)

*The Supplier Risk Matrix combines financial exposure, operational risk, and decision thresholds into a single, intuitive visualization.*

### Contract Intelligence Dashboard

![Contract Intelligence Dashboard](docs/images/dashboard_contract.png)

*The Strategic Contract Matrix identifies products with high contract attractiveness and positive demand momentum.*

### Supplier Development Dashboard

![Supplier Development Dashboard](docs/images/dashboard_supplier.png)

*The Supplier Portfolio Quadrant segments suppliers by operational quality and business importance.*

---

## 💾 SQL Logic Summary

### Engine 1: Supplier Risk Management

```sql
-- Weighted scorecard: Spend 30% + Errors 30% + Rejections 20% + Risk 20%
-- Decision thresholds: ≥70 Replace | 40-69 Monitor | <40 Retain

### Engine 2: Contract Intelligence

-- Weighted scorecard: Spend 30% + Frequency 25% + Consistency 20% + Volatility 15% + Concentration 10%
-- Phase-Out Override: YoY < -50% AND 2025 spend < 25% of 2023 spend

### Engine 3: Supplier Development
-- 5-dimension scoring model with fixed business thresholds
-- Strategic flags overlay: Concentration, Consolidation, Declining

[Full SQL scripts are available in the `mysql/` directory.](./mysql/)

📚 Documentation
Document	Description
Executive Summary	3-page executive overview for leadership
Full Project Report	Complete documentation including methodology, findings, and recommendations
🔍 Key Insights
Hero Finding 1: Static Risk Labels Are Unreliable
"Low Risk" does not mean "Low Friction."

Vintage Store (the sole "High Risk" vendor) performs flawlessly: 0% errors, 3.6% rejections.

Accenture (classified "Low Risk") drives the highest error rate: 10.71%, 4.7× above average.

Hero Finding 2: Concentration Risk Is Dominant
Concentration risk, not supplier quality, is the dominant portfolio issue.

10 out of 12 suppliers have limited product diversity (≤2 categories).

$87.7M in spend exposed to single-product dependency.

Hero Finding 3: Only One Immediate Contract Candidate
Traditional aggregate analysis would have recommended contracts for dying products.

Power Tools is the only immediate contract candidate: $2.47M spend, 130% growth.

35+ products flagged for phase-out due to demand collapse (e.g., Implementation Service: -93.8%).

👤 Author
Oje Ebhota
July 2026

📄 License
This project is licensed under the MIT License - see the LICENSE file for details.

🙏 Acknowledgments
This project was developed as a comprehensive analytics solution for procurement decision support. All data used is synthetic. The project demonstrates SQL engineering, business logic development, and executive reporting capabilities.

## About Me

I am **Oje Ebhota**, a **multidisciplinary professional** with a diverse background spanning **Electrical Engineering, ERP/CRM systems, AI Automation, and Data Analytics (DA)**. As a **data-driven analyst**, I specialize in transforming raw data into actionable insights that drive strategic decision-making.

My expertise includes:
- **Data Analytics & Business Intelligence**: Leveraging **SQL, Python, and visualization tools** to uncover trends, optimize processes, and mitigate risks.
- **ERP/CRM Systems**: Implementing and optimizing systems to streamline operations and enhance efficiency.
- **AI Automation**: Developing intelligent solutions to automate workflows and improve productivity.
- **Cross-Industry Applications**: Applying my skills across various sectors to solve complex problems and drive innovation.

I thrive at the intersection of **data, business strategy, and storytelling**, empowering organizations to make smarter, more informed decisions. Whether it's procurement, operations, or beyond, I bring a **versatile toolkit** and a passion for turning data into impact.
