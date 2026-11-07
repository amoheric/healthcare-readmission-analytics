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

The user supplied browser screenshots of all five Streamlit pages on November 4, 2026. All five page titles, expected chart/table sections, and model-evaluation cautions were visible. This is a **screen-capture review of rendered states**, not a live browser automation test. Patient Demographics shows the Age tab, Healthcare Utilization shows Admission Types, and Model Evaluation shows one selector state; alternate tabs and interactions were not verified.

### Updated portfolio image

The Power BI screenshot at `docs/screenshots/power_bi_dashboard.png` was updated again on the draft branch using the user's final clean capture. The screenshot now has the corrected “Not Readmitted Within 30 Days” label, two gender bars (Female, Male), six admission-type bars and a notice excluding subgroups with fewer than 30 encounters from displayed rates. The source aggregate CSVs are unchanged and continue to expose original small counts. The PBIX file has now been replaced on the draft branch using the author's final Power BI Desktop save; `main` remains unchanged until PR #2 is merged.

## Open release gates

- [x] Power BI Desktop opened, main KPIs rendered, the age-group chart selected/highlighted successfully, and the outcome KPI label was corrected to “Not Readmitted Within 30 Days” (user-provided screenshots).
- [ ] Check other intended cross-visual interactions, report refresh, and any model measures not covered by the screenshot-based review.
- [x] Five deployed Streamlit pages rendered in user-provided browser screenshots (Executive Overview, Patient Demographics, Healthcare Utilization, Predictive Modeling, Model Evaluation); no visible application errors in captured states.
- [x] User reports the tested Streamlit tabs and interactive selectors work. The five-page screenshot review and this user confirmation support basic functioning; exhaustive combinations and automated browser testing were not conducted.
- [x] Define an [interpretive low-denominator display rule](small_cell_presentation_policy.md): omit subgroup rate estimates for n < 30 in Streamlit and flag remaining low-event groups.
- [ ] Verify the new Streamlit branch code runs correctly after deployment; the user-confirmed interactive controls refer to the earlier deployed version.
- [x] User supplied a clean Power BI screenshot confirming gender/admission visual filtering, the corrected KPI wording, and unchanged 86,547 / 9,677 / 11.18% totals. The screenshot has been updated on this draft branch.
- [x] The author supplied the updated Power BI Desktop PBIX. The new binary was checked as a valid Power BI ZIP/PBIR package, with the corrected KPI label, both visual-only `total_encounters >= 30` filters, and the explanatory note present. The updated PBIX now replaces `dashboard/healthcare_readmission_dashboard.pbix` on this draft branch. Further Power BI Desktop refresh tests have not been automated.
- [ ] Complete formal small-cell disclosure/linked-aggregate review if privacy suppression is required. The published aggregate CSVs still reveal small counts; the display rule is not privacy protection.
- [ ] Confirm presentation labels keep **C0 BI (86,547 encounters, 9,677 events)** distinct from **C2 research modeling (84,471 encounters, 9,643 events)**.
- [ ] Review/publicly release revised P1/P2/P2B research materials only after privacy and reproducibility checks.

**Use:** Historical retrospective research/portfolio presentation, not live clinical decision support.
