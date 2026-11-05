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

**Status:** Scientific manuscript under advisor review; targeted local reproducibility checks passed, but public full reproduction, clinical validation and final dashboard interactive QA are not complete. This is not a clinical tool.
