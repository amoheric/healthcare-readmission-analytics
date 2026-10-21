# HGB Model Evaluation — Streamlit Reporting Contract

## 1. Research Source

Primary source: `notebooks/07_model_validation.ipynb`

Supporting source:
`reports/notebook07_validation_metadata.json`

Model: Histogram Gradient Boosting (HGB).

## 2. Evaluation Boundary

- Development encounters: 86,547.
- Unique development patients: 60,790.
- Validation strategy: five-fold StratifiedGroupKFold.
- Patient grouping variable: `patient_nbr`.
- Held-out test partition loaded: No.
- Preprocessing performed within validation folds.
- Reported performance: pooled out-of-fold development estimates.

The HGB model family and hyperparameters were previously selected
using the development cohort. These results are not fully independent
generalization estimates.

## 3. Approved Aggregate Reporting Sources

### Fold performance

Source: `reports/notebook07_fold_performance.csv`

Permitted:
- Fold number.
- Training and evaluation encounter counts.
- Training and evaluation patient counts.
- Evaluation prevalence.
- ROC-AUC.
- Average precision.
- Brier score.
- Computational evaluation time.

### Bootstrap uncertainty

Source: `reports/notebook07_patient_bootstrap_summary.csv`

Permitted:
- Metric name.
- Point estimate.
- Bootstrap mean and standard deviation.
- 95% confidence interval bounds.

Interpretation:
Patient-bootstrap sampling uncertainty for fixed OOF predictions.
Intervals exclude model-refitting variability.

### Responsible evaluation

Source: `reports/notebook07_responsible_evaluation_summary.csv`

Permitted:
- Overall performance.
- Calibration estimates.
- Development screening threshold.
- Screening sensitivity and specificity.
- Predicted-positive rate.
- Clearly labeled descriptive subgroup contrasts.

### Subgroup disparity summaries

Source: `reports/notebook07_subgroup_disparity_summary.csv`

Permitted:
- Attribute and metric.
- Minimum and maximum reported groups.
- Corresponding aggregate estimates.
- Absolute observed range.
- Number of groups compared.

Observed ranges must not be substituted for prespecified contrasts
or interpreted as evidence of causation.

## 4. Validated Reference Results

- Pooled OOF ROC-AUC: approximately 0.643929.
- Pooled OOF average precision: approximately 0.198375.
- Pooled OOF Brier score: approximately 0.096059.
- Expected calibration error: approximately 0.004056.
- Development screening threshold: 0.095.
- Sensitivity: approximately 0.701147.
- Specificity: approximately 0.492078.
- Predicted-positive rate: approximately 0.529527.

Full numerical precision must come from validated source artifacts.

## 5. Privacy and Publication Restrictions

Do not publish:
- Patient identifiers.
- Encounter identifiers.
- Individual prediction records.
- Individual predicted probabilities.
- Patient-level bootstrap samples.
- Raw or processed encounter-level healthcare datasets.
- Trained model objects.

The Streamlit application must load only explicitly approved,
validated aggregate reporting artifacts.

## 6. Interpretation Restrictions

- Do not label HGB OOF metrics as held-out test performance.
- Do not imply clinical deployment readiness.
- Do not claim external validation.
- Do not make causal interpretations.
- Do not claim statistical significance without supporting analysis.
- Do not present subgroup disparities without methodological context.
- Do not compare HGB OOF metrics directly against Random Forest
  held-out test metrics as though evaluation procedures were identical.

## 7. Deployment

The deployed dashboard must operate using curated aggregate files.
It must not require PostgreSQL access, raw healthcare data,
patient-level predictions, or persisted trained models.
