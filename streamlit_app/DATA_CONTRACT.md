# Streamlit Data Contract

## Purpose

Define the approved analytical inputs, data boundaries,
and validation requirements for the public Healthcare
Readmission Analytics Streamlit application.

## Dataset Provenance

The application uses derived reporting aggregates from the
UCI Diabetes 130-US Hospitals for Years 1999–2008 dataset.

The source represents historical hospital encounters, not
contemporary clinical operations.

The Streamlit application uses approved aggregate exports
rather than the source encounter-level dataset.

Source attribution and applicable reuse or redistribution
terms must be verified before public deployment.

## Cohort Definition

The descriptive dashboard represents the development cohort:

- Training encounters: 71,520
- Validation encounters: 15,027
- Total encounters: 86,547
- Readmitted within 30 days: 9,677
- Other encounters: 76,870
- Observed 30-day readmission rate: 11.18%

These figures are encounter-level historical summaries.

The independent test partition is excluded from the
descriptive PostgreSQL reporting dataset.

## Approved PostgreSQL Exports

All sources belong to the reporting schema.

| Export | Source View |
|---|---|
| readmission_kpi.csv | vw_readmission_kpi |
| readmission_by_partition.csv | vw_readmission_by_partition |
| readmission_by_age.csv | vw_readmission_by_age |
| readmission_by_gender.csv | vw_readmission_by_gender |
| readmission_by_race.csv | vw_readmission_by_race |
| readmission_by_admission_type.csv | vw_readmission_by_admission_type |
| readmission_by_los.csv | vw_readmission_by_los |
| utilization_by_outcome.csv | vw_utilization_by_outcome |
| data_completeness.csv | vw_data_completeness |

Export destination:

streamlit_app/data/sql_exports/

## Validation Requirements

Before publication:

1. Verify export schemas against PostgreSQL reporting views.
2. Confirm expected row counts.
3. Confirm KPI totals: 86,547 encounters and 9,677 readmissions.
4. Reconcile category-level encounter and readmission totals.
5. Confirm percentages and utilization summaries match SQL outputs.
6. Inspect exports for identifiers or unnecessary granular records.
7. Confirm that no credentials or secrets are present.
8. Verify that the Streamlit application reads the approved exports.

## Model Evaluation Boundaries

Random Forest held-out test results and HGB patient-grouped
out-of-fold validation results must be identified separately.

Do not describe HGB out-of-fold results as independent
held-out test performance.

Use only validated research reports with documented
evaluation methods and limitations.

## Small-Cell Reporting Policy

Small demographic categories are explicitly flagged for
interpretation and disclosure review.

The gender category Unknown/Invalid contains one encounter
and zero readmissions in the development cohort.

The public reporting layer currently retains this aggregate
category for numerical reconciliation and transparency.
It must not be interpreted as a reliable subgroup estimate.

Removing this category alone would not conceal its count,
because the overall cohort total and the other gender
category totals are also reported.

The HGB evaluation excludes this insufficient-sample
category from comparative performance charts and does not
estimate its undefined performance metrics.

This reporting policy is not a claim of formal disclosure
control, anonymization certification, or HIPAA compliance.

Final publication remains contingent on provenance,
redistribution, and disclosure review.

## Public Data Restrictions

Do not publish the following as Streamlit application data:

- Raw encounter-level datasets.
- Training, validation, or test encounter-level files.
- Encounter-level out-of-fold prediction records.
- Patient or encounter identifiers.
- SQL QA datasets.
- Local database credentials.
- API keys or authentication secrets.

## Interpretation Requirements

- Label descriptive results as development-cohort findings.
- Distinguish observed associations from causal effects.
- Show category sample sizes alongside percentages.
- Flag categories with very small sample sizes.
- Distinguish unrecorded laboratory values from confirmed
  absence of testing.
- Document model validation limitations.
- Do not present the application as a clinical decision tool.

## Publication Status

Dataset provenance identified: Completed.
SQL aggregate exports: Completed.
CSV/JSON structural validation: Completed.
Preliminary content-level privacy screening: Completed.
Preliminary small-cell disclosure review: Completed; final publication assessment pending.
Streamlit implementation: Completed; final QA pending.
Source license and attribution verification: Verified against the
official UCI Machine Learning Repository dataset record.

### Source Dataset Attribution and License

Clore, J., Cios, K., DeShazo, J., & Strack, B. (2014).
*Diabetes 130-US Hospitals for Years 1999–2008* [Dataset].
UCI Machine Learning Repository.
https://doi.org/10.24432/C5230J

License: Creative Commons Attribution 4.0 International (CC BY 4.0).
https://creativecommons.org/licenses/by/4.0/

The original dataset contains 101,766 historical hospital encounters.

This project's descriptive reporting exports represent the
86,547-encounter development cohort after research preprocessing,
partitioning, and aggregation. They are derived analytical reports,
not unmodified copies of the original dataset.

The source dataset's creators and the UCI Machine Learning Repository
are credited above. This project is an independent portfolio analysis
and is not affiliated with or endorsed by UCI.

Source licensing verification does not constitute completion of the
separate data privacy and small-cell publication review.
Final disclosure and publication review: Pending.
Public deployment: Pending.
