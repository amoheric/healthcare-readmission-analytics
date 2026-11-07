# Reproducibility and responsible release status

**Research v1.1 is partially verified locally; it is not yet a self-contained public reproduction release.** Existing notebooks/SQL/Power BI/Streamlit files predate the revised P0/P1/P2/P2B experiment pipeline.

| Evidence | Status | What it does not prove |
| --- | --- | --- |
| Source and feature audits | Raw/source schema and frozen 48-feature contract pass | Prospective clinical predictor timing |
| G3A manifest | 81 files match SHA-256 | Original model calculations are correct |
| P0/P1 unit tests | 20 of 20 passed | Every historical full-data fit was correct |
| G3B boundary audit | 3 seeds × 5 folds passed saved checks | Independent regeneration of patient-level boundaries |
| G3B.4 selected-candidate replay | User-reported 182 comparisons, 0 mismatches, seed 42/fold 1 LR/HGB | Full five-fold, three-seed pipeline reproduction |
| SQL/BI aggregate QA | 75/75 static checks and 17/17 local PostgreSQL checks passed | Live dashboard interactions or final disclosure policy |

**Before calling this research reproducible from the public repository:** review/release the frozen P0/P1/P2/P2B scripts and tests, environment locks, configuration, input acquisition instructions, aggregate evidence maps and clean-environment run instructions; then test those instructions. Do not imply the existing public main branch already reproduces the newer manuscript.

**Never publish** raw or processed encounter-level rows, encounter/patient identifiers, fold-boundary NPZ files, individual out-of-fold predictions, credentials or private workspaces. Small aggregate cells also require disclosure review; publishing only aggregates is not automatically safe.

The manuscript remains an author-prepared draft for possible advisor review; external academic review has not been documented. Journal-readiness and ethics declarations are outstanding. Neither code nor dashboard represents clinical decision-support software.

See [research results](revised_readmission_study_v1_1.md) and [portfolio QA](../portfolio/qa_status_2026_11.md).
