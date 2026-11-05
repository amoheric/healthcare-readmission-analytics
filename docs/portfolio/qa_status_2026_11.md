# Portfolio verification — November 2026

**Verified scope:** the existing SQL/BI **C0 development cohort**; not the revised manuscript's C2 modeling cohort.

## Automated checks confirmed in the user's local run

| Check | Result |
| --- | ---: |
| Static dashboard/export checks | **75/75 PASS** |
| Read-only PostgreSQL assertions | **17/17 PASS** |
| Development encounters | **86,547** |
| Recorded <30-day readmissions | **9,677** |
| Observed readmission rate | **11.18%** |
| Train / validation encounters | **71,520 / 15,027** |
| Unique development patients | **60,790** |
| Held-out test records in development reporting tables | **0** |

The database QA transaction was rolled back. Published aggregate exports reconcile across age, gender, race, admission type, length of stay and partition. This is not proof that dashboard interactivity was tested.

## Existing artifacts

- [PostgreSQL SQL scripts](../../sql/) and [data contract](../../sql/00_sql_data_contract.md)
- [Power BI PBIX](../../dashboard/healthcare_readmission_dashboard.pbix) and [screenshot](../screenshots/power_bi_dashboard.png)
- [Five-page Streamlit app](../../streamlit_app/) and [public app link](https://healthcare-readmission-analytics-i3gcjyhxok3hynnwe7trda.streamlit.app)

The published Power BI screenshot has been inspected for static KPI agreement; the PBIX itself has **not** been interactively verified in Power BI Desktop.

## Open release gates

- [ ] Verify Power BI refresh, slicers, charts and calculations in Desktop.
- [ ] Open all five deployed Streamlit pages and test rendering/interactions.
- [ ] Complete public small-cell disclosure review. Very small categories exist in published gender/admission summaries; suppressing a single category may allow reconstruction from totals.
- [ ] Confirm presentation labels keep **C0 BI (86,547 encounters, 9,677 events)** distinct from **C2 research modeling (84,471 encounters, 9,643 events)**.
- [ ] Review/publicly release revised P1/P2/P2B research materials only after privacy and reproducibility checks.

**Use:** Historical retrospective research/portfolio presentation, not live clinical decision support.
