# Healthcare Readmission Analytics — one-minute portfolio walkthrough

**Problem:** Investigate observed 30-day readmission patterns and test whether historical encounter features discriminate readmission risk, while reporting the limits of internal validation.

**Data boundaries:** 101,766 source hospital encounters; the descriptive PostgreSQL/Power BI/Streamlit dashboard uses **86,547 development encounters**, while the revised manuscript uses **84,471 C2 development encounters** after further exclusions. These are different analytical populations.

**Methods/stack:** Python, pandas, scikit-learn, patient-aware nested model evaluation, calibration, patient-cluster resampling; PostgreSQL schemas/views and read-only QA; a Power BI report and five-page Streamlit application.

**Research highlight:** In revised seed-42 C2 internal evaluation, calibrated HGB had AUROC **0.6456** and Brier **0.097728**. A sensitivity target around 70% flagged **52.9%** of evaluation encounters, illustrating potential operational false-positive burden rather than clinical benefit.

**View the work:**
- [Live Streamlit dashboard](https://healthcare-readmission-analytics-i3gcjyhxok3hynnwe7trda.streamlit.app)
- [Power BI executive screenshot](../screenshots/power_bi_dashboard.png)
- [SQL data contract](../../sql/00_sql_data_contract.md) and [reporting views](../../sql/05_reporting_views.sql)
- [Revised study summary](../research/revised_readmission_study_v1_1.md)
- [Reproducibility scope](../research/reproducibility_status.md) and [dashboard QA](qa_status_2026_11.md)

**Status:** Scientific manuscript drafted for potential advisor feedback (not yet externally reviewed); targeted local reproducibility checks passed, but public full reproduction, clinical validation and final dashboard interactive QA are not complete. This is not a clinical tool.


## What the research numbers mean — without overstating them

- **AUROC 0.6456:** Some ability to rank recorded readmissions ahead of non-readmissions, but only **modest discrimination**; it does **not** mean 64.56% of patients were classified correctly.
- **Brier score 0.097728:** Average squared error of estimated probabilities (lower is better). The HGB advantage over logistic regression was **small** in absolute terms; it does not demonstrate clinical usefulness.
- **70.12% sensitivity:** Around 70 of 100 encounters with recorded <30-day readmission were flagged at the chosen threshold.
- **15.14% positive predictive value (PPV):** Of 100 flagged encounters, only about 15 had the recorded outcome.
- **52.87% alert rate:** About **529 of every 1,000 encounters** would be flagged in this retrospective C2 evaluation: approximately **80 true-positive** and **449 false-positive** alerts. These are simulated counts from historical model outputs, **not** observed alerts in a hospital.
- **C0 vs. C2:** SQL/Power BI descriptive totals use **86,547 C0 encounters**, whereas the revised model comparison uses **84,471 C2 encounters** after exclusions. These are different denominators.
- **20/20 unit tests, 81/81 evidence hashes and 182 replay comparisons:** Checks with different scopes—not **223 independent confirmations** of accuracy. No prospective/external clinical validation or full public reproduction has been completed.
