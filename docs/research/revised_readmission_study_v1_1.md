# Revised retrospective readmission study (v1.1)

> **Research draft prepared for potential advisor review; not externally reviewed, peer reviewed or clinically validated.** The updated P0/P1/P2/P2B experiments were conducted outside the historical notebook/BI workflow. Their complete training-code reproduction bundle is **not yet publicly released** here.

## Objective and boundaries

This research examines the discrimination, calibration, robustness and subgroup behavior of models for **recorded readmission within 30 days** in the [UCI Diabetes 130-US Hospitals dataset](https://doi.org/10.24432/C5230J), which includes **101,766 historical hospital encounters**.

| Reporting surface | Cohort | Encounters | Recorded <30 readmissions | Patients |
| --- | --- | ---: | ---: | ---: |
| Existing PostgreSQL, Power BI, descriptive Streamlit | C0 development (train + validation) | 86,547 | 9,677 | 60,790 |
| Revised manuscript internal evaluation | C2 development with death/hospice exclusions | 84,471 | 9,643 | 59,485 |

**Do not compare older notebook held-out Random Forest or notebook-07 HGB OOF scores directly with the newer P1 C2 estimates.** Their cohorts and evaluation protocols differ, and an older notebook's held-out test partition had documented reuse.

## Revised methods

- Five patient-grouped outer folds with nested tuning; additional seeds **42, 43 and 44** explored sensitivity to partitioning.
- Logistic regression (LR), random forest (RF) and histogram gradient boosting (HGB) compared under C2; additional HGB C0/C1 cohort-policy comparisons.
- Sigmoid calibration and a calibration-selected operating point targeting approximately 70% sensitivity.
- Patient-cluster paired bootstrap using 2,000 replicates, conditional on **fixed out-of-fold predictions**. Intervals do not cover the full refitting/model-selection process.
- Frozen contract of **48 predictors** (13 numeric, 35 categorical). Direct outcome, patient identifiers, encounter IDs and discharge disposition were excluded from predictors.
- Prediction framing is **retrospective finalized-encounter analysis**. Discharge-time operational availability of every input has not been established.

## Primary seed-42 calibrated C2 results

| Model | AUROC | Average precision | Brier score |
| --- | ---: | ---: | ---: |
| LR | 0.6413 | 0.1962 | 0.098044 |
| RF | 0.6465 | 0.2014 | 0.097735 |
| HGB | 0.6456 | 0.2021 | 0.097728 |

HGB minus LR Brier difference: **−0.0003164**, with conditional 95% paired patient-bootstrap interval **[−0.0004587, −0.0001821]**. The HGB–RF Brier difference was approximately **−0.0000073**; its interval includes zero, so **superiority to RF was not established**.

At the calibration-selected sensitivity-target threshold, HGB had **70.12% sensitivity**, **15.14% positive predictive value**, and flagged **52.87% of encounters** (approximately **449 false positives per 1,000 encounters**). This shows the possible alert burden, **not** a demonstrated clinical benefit.

## Evidence and remaining limitations

- G1 raw-source audit: discharge code 21 absent in frozen input.
- G2: static 48-feature contract, configuration and raw-schema checks passed; actual prospective feature availability **not** verified.
- G3A: **81 archived files** matched their SHA-256 manifest (0 mismatches).
- G3B: **20/20** P0/P1 unit tests passed, and saved-boundary membership/coverage checks passed for **3 seeds × 5 folds**. Saved boundaries were not independently regenerated.
- G3B.4: author-reported local selected-candidate replay for **seed 42/fold 1 LR and HGB** found **182 comparisons, 0 mismatches**. This is not a full independent reproduction; the replay JSON has not been separately inspected here.

The manuscript requires remaining author declarations, ethics/reporting review, and a safe public research-code release. There is no prospective or external validation, clinical utility assessment, or fairness certification.

**Provenance:** numerical tables from the frozen v1.1 evidence package (Table 1, Tables 2–4 and accompanying aggregates), not from the older public dashboard model results. Dataset citation: Clore et al., UCI, DOI [10.24432/C5230J](https://doi.org/10.24432/C5230J).

See [release limitations](reproducibility_status.md).
