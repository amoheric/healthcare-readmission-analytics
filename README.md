# Healthcare Readmission Analytics

An end-to-end healthcare analytics and machine-learning project using the UCI Diabetes 130-US Hospitals for Years 1999–2008 dataset to investigate 30-day hospital readmission risk.

The project combines data auditing, preprocessing, exploratory analysis, feature engineering, predictive modeling, patient-aware validation, model interpretability, PostgreSQL analytics, and BI reporting.

> **Portfolio note:** This project is designed to demonstrate analytical reasoning, machine-learning evaluation discipline, SQL/data engineering, responsible model assessment, and communication of findings. It is not a clinical decision-support system and should not be used for patient-care decisions.

---

## Problem & Objective

Hospital readmissions are an important operational and healthcare-quality concern.

The objective of this project is to analyze encounter-level healthcare data and build models that estimate whether a patient encounter is associated with a **30-day readmission outcome**.

The project focuses on:

- Understanding the structure and quality of the source data
- Preparing reproducible analytical features
- Investigating patterns associated with 30-day readmission
- Establishing a baseline predictive model
- Optimizing and comparing candidate models
- Evaluating performance using a locked held-out test partition
- Performing patient-aware out-of-fold validation
- Examining model robustness across demographic groups
- Interpreting model behavior and feature contributions
- Building a PostgreSQL reporting layer for BI consumption
- Preparing the results for an executive-facing dashboard

---

## Project Architecture

```text
UCI Healthcare Dataset
        │
        ▼
01 — Data Audit
        │
        ▼
02 — Data Preprocessing
        │
        ▼
03 — Exploratory Data Analysis
        │
        ▼
04 — Feature Engineering
        │
        ▼
05 — Baseline Predictive Modeling
        │
        ▼
06 — Model Optimization
        │
        ▼
07 — Patient-Aware Validation
        │
        ▼
08 — Model Interpretability
        │
        ├──────────────► Model / interpretation artifacts
        │
        ▼
PostgreSQL 18
        │
        ├── staging
        ├── analytics
        └── reporting
              │
              ├── KPI
              ├── Partition
              ├── Age
              ├── Gender
              ├── Race
              ├── Admission Type
              ├── Length of Stay
              ├── Utilization
              └── Data Completeness
                         │
                         ▼
                    Power BI
```

---

## Dataset & Evaluation Boundary

The project uses the UCI **Diabetes 130-US Hospitals for Years 1999–2008** dataset.

The modeling workflow separates development data from an independent held-out test partition.

The development cohort contains:

**86,547 encounters**

The development cohort consists of:

- Training partition: **71,520 encounters**
- Validation partition: **15,027 encounters**

The held-out test partition is kept separate from development-stage modeling and validation.

This distinction is important because model selection and model evaluation should not be treated as the same activity.

## Evaluation principle

The project maintains the following boundary:

```text
Development data
    │
    ├── model development
    ├── optimization
    ├── patient-aware validation
    └── interpretability

Held-out test data
    │
    └── independent evaluation of the selected optimized model
```

The later Histogram Gradient Boosting analysis is therefore reported as **development-stage patient-aware validation evidence**, rather than as a new independent held-out test result.

---

## Analytical Workflow

### 01 — Data Audit

The first stage examines the raw dataset structure and establishes the foundation for downstream analysis.

The audit addresses:

- Dataset dimensions
- Variable types
- Missing and placeholder values
- Categorical distributions
- Numeric ranges
- Duplicate/identifier considerations
- Target distribution
- Data-quality observations

The purpose is to understand the source data before making modeling decisions.

---

### 02 — Data Preprocessing

The preprocessing stage converts the raw healthcare data into a modeling-ready representation.

Key activities include:

- Handling source missing-value conventions
- Standardizing analytical representations
- Preparing categorical variables
- Preparing numeric variables
- Defining the modeling target
- Establishing development/test boundaries
- Preserving patient-level information needed for grouped validation

---

### 03 — Exploratory Data Analysis

The EDA stage investigates the relationship between encounter characteristics and 30-day readmission.

Areas examined include:

- Demographic characteristics
- Hospital utilization
- Length of stay
- Laboratory procedures
- Procedures
- Medication counts
- Diagnosis counts
- Admission characteristics
- Readmission outcome distribution

The purpose is descriptive: observed differences are not interpreted automatically as causal effects.

---

### 04 — Feature Engineering

Feature engineering converts the prepared source variables into representations suitable for predictive modeling.

The resulting analytical dataset contains the engineered modeling features used throughout the predictive workflow.

Feature engineering was performed before model optimization and validation so that downstream model comparisons operate on a consistent analytical representation.

---

### 05 — Baseline Predictive Modeling

A baseline modeling stage establishes an initial performance reference before optimization.

The baseline workflow evaluates candidate approaches using the development data and ultimately evaluates the baseline model on the independent held-out test partition.

The baseline provides a reference point for determining whether subsequent optimization produces meaningful improvement.

---

### 06 — Model Optimization

The optimization stage evaluates additional modeling strategies and hyperparameter configurations.

The workflow includes:

- Controlled hyperparameter optimization
- Ensemble-model comparison
- Probability-quality assessment
- Threshold analysis
- Final model selection
- Independent held-out test evaluation

The optimization process does not treat the highest single metric as sufficient evidence of model quality.

Instead, model selection considers the intended screening objective and multiple performance measures.

---

## Final Model Results

### Optimized Random Forest — Independent Held-Out Test

The optimized Random Forest was selected for the original independent held-out test evaluation.

| Metric | Result |
|---|---:|
| ROC-AUC | **0.6494** |
| Average Precision | **0.2033** |
| Brier Score | **0.2188** |
| Sensitivity | **75.48%** |
| Specificity | **43.36%** |
| Operating threshold | **0.43** |

The selected threshold reflects a screening-oriented operating objective rather than an assumption that the default 0.50 probability threshold is always optimal.

The held-out test evaluation provides the independent generalization estimate for this selected optimized Random Forest.

---

### Candidate Model: Histogram Gradient Boosting

Histogram Gradient Boosting was subsequently investigated as a development-stage candidate.

Its evaluation is intentionally described differently from the optimized Random Forest because the analysis occurred after the original locked held-out test evaluation.

The model was evaluated using patient-aware out-of-fold validation.

### Patient-aware validation

The validation workflow uses:

**5-fold StratifiedGroupKFold**

with patient grouping based on:

```text
patient_nbr
```

This prevents encounters belonging to the same patient from being split across training and evaluation folds.

### Pooled OOF results

| Metric | Result |
|---|---:|
| ROC-AUC | **0.6439** |
| Average Precision | **0.1984** |
| Brier Score | **0.0961** |
| ROC-AUC 95% patient-bootstrap CI | **0.6377–0.6503** |
| Expected Calibration Error | **0.0041** |

These results provide useful development-stage evidence about model stability, discrimination, and probability quality.

They are **not presented as an independent held-out test estimate**.

---

## Why the Evaluation Boundary Matters

A major design principle of this project is avoiding evaluation leakage in the reporting narrative.

The project distinguishes between:

### Independent test evidence

Used for the selected optimized Random Forest.

### Patient-aware OOF evidence

Used to evaluate the later Histogram Gradient Boosting candidate across patient-grouped folds.

This distinction prevents a development-stage model from being presented as though it had received an untouched independent test evaluation.

That distinction is intentional and is part of the project's responsible machine-learning methodology.

---

### 07 — Patient-Aware Validation

Validation goes beyond a single aggregate performance number.

The validation workflow examines:

- Fold-level performance
- Out-of-fold predictions
- Patient-level bootstrap uncertainty
- Calibration
- Threshold behavior
- Age subgroup performance
- Gender subgroup performance
- Race subgroup performance
- Disparity contrasts
- Robustness across patient groups

This provides a more realistic assessment of how the model behaves when multiple encounters from the same patient are present in the underlying healthcare data.

---

## Responsible ML & Robustness

Model performance is not evaluated solely by overall discrimination.

The project also investigates subgroup behavior and potential robustness limitations.

One important finding is **age-related heterogeneity**.

The validation evidence identifies a substantial difference in ROC-AUC between older patients and the younger reference grouping, along with a notable false-positive-rate contrast.

The reported age-related robustness contrast includes:

- ROC-AUC difference for age 70+ versus ages 20–49: approximately **−0.1136**
- False-positive-rate difference: approximately **+0.2066**

Gender and race contrasts were smaller in the reported validation analyses.

These findings do not establish that the model is clinically unfair or causally biased. They indicate that model performance varies across evaluated subgroups and that additional validation would be necessary before any real-world clinical deployment.

---

### 08 — Model Interpretability

Interpretability analysis investigates model behavior from multiple perspectives rather than relying on a single feature-importance technique.

The project includes:

- Permutation importance
- Grouped permutation importance
- Feature-family analysis
- Utilization concept analysis
- Partial dependence analysis
- Categorical profiling
- Feature lineage
- Support diagnostics
- Evidence triangulation

The goal is to identify recurring patterns across multiple analytical methods.

Interpretability findings are treated as associations with model predictions, not as causal explanations.

---

## Evidence Triangulation

The interpretability workflow combines multiple sources of evidence.

```text
Global feature importance
          │
          ├──────────────┐
          ▼              ▼
Grouped importance    Feature families
          │              │
          └──────┬───────┘
                 ▼
        Utilization concepts
                 │
                 ▼
       Partial dependence
                 │
                 ▼
       Categorical profiles
                 │
                 ▼
        Evidence triangulation
```

When several methods point toward the same analytical concept, confidence in the **descriptive pattern** increases.

This does not convert model associations into causal claims.

---

## PostgreSQL Analytics Layer

PostgreSQL 18 provides the project's analytical and BI reporting layer.

The database separates data responsibilities into:

```text
staging
    │
    └── validated loaded development data

analytics
    │
    └── modeling / analytical dataset

reporting
    │
    └── presentation-ready reporting views
```

The SQL workflow is organized as:

```text
sql/
├── 00_sql_data_contract.md
├── 01_schema.sql
├── 02_load_development_data.sql
├── 03_readmission_kpis.sql
├── 04_build_model_dataset.sql
└── 05_reporting_views.sql
```

---

## Reporting Views

The reporting schema currently contains nine reusable views:

| View | Purpose |
|---|---|
| `vw_readmission_kpi` | Overall readmission KPI |
| `vw_readmission_by_partition` | Training vs. validation partition summary |
| `vw_readmission_by_age` | Readmission by age group |
| `vw_readmission_by_gender` | Readmission by gender |
| `vw_readmission_by_race` | Readmission by race |
| `vw_readmission_by_admission_type` | Readmission by admission type |
| `vw_readmission_by_los` | Readmission by length of stay |
| `vw_utilization_by_outcome` | Utilization comparison by readmission outcome |
| `vw_data_completeness` | Selected data-completeness indicators |

The reporting views operate on the development analytical dataset and do not modify the machine-learning workflow.

---

## SQL Reporting Results

The PostgreSQL reporting layer confirms the development cohort contains:

- **86,547 total encounters**
- **9,677 30-day readmissions**
- **76,870 non-readmissions**
- **11.18% overall 30-day readmission rate**

The development partitions are:

| Partition | Encounters | Readmissions | Rate |
|---|---:|---:|---:|
| Train | 71,520 | 8,021 | 11.22% |
| Validation | 15,027 | 1,656 | 11.02% |

The similar target distributions between the development partitions provide a useful data-quality and modeling-readiness check.

---

## Descriptive Findings

### Age

Observed readmission rates vary across age groups.

For example:

- `[20-30)` — **15.09%**
- `[80-90)` — **12.16%**
- `[70-80)` — **11.79%**
- `[50-60)` — **9.35%**
- `[0-10)` — **2.22%**

These are descriptive differences in the development cohort and should not be interpreted as causal effects.

---

### Admission Type

Emergency encounters have an observed readmission rate of approximately:

**11.56%**

compared with approximately:

**10.47%**

for elective encounters.

Again, these values describe observed differences in this dataset rather than causal effects.

---

### Length of Stay

Observed readmission rates generally increase across shorter-to-moderate lengths of stay before becoming more variable at the longest stay durations.

Examples include:

- 1 day — **8.30%**
- 4 days — **11.71%**
- 6 days — **12.45%**
- 8 days — **14.39%**
- 10 days — **14.37%**

Length of stay is therefore useful as a descriptive operational variable, but these results do not establish that length of stay causes readmission.

---

### Utilization

The reporting layer compares utilization characteristics between encounters with and without a 30-day readmission.

| Measure | No 30-day Readmission | 30-day Readmission |
|---|---:|---:|
| Average length of stay | 4.35 | 4.77 |
| Average lab procedures | 42.98 | 44.31 |
| Average medications | 15.92 | 16.87 |
| Average outpatient visits | 0.36 | 0.43 |
| Average emergency visits | 0.18 | 0.36 |
| Average inpatient visits | 0.56 | 1.22 |
| Average diagnoses | 7.39 | 7.69 |

The strongest descriptive utilization difference shown here is in prior inpatient utilization.

These values are observational summaries, not causal estimates.

---

## Power BI Dashboard

**Status: Dashboard completed**

The PostgreSQL `reporting` schema serves as the data source for the Power BI dashboard.

The completed executive dashboard presents the validated reporting outputs through a concise analytical interface covering:

### Executive KPIs

- Total encounters
- 30-day readmissions
- 30-day readmission rate
- Non-readmitted encounters
- Selected data-completeness indicators

### Demographic analysis

- 30-day readmission rate by age group
- 30-day readmission rate by gender
- 30-day readmission rate by race

### Operational analysis

- 30-day readmission rate by admission type
- 30-day readmission rate by length of stay
- Healthcare utilization by 30-day readmission status

### Data-quality indicators

The dashboard includes selected completeness indicators from the PostgreSQL reporting layer, including:

- A1C not recorded
- Maximum glucose not recorded
- Race unknown

These indicators are presented as data-quality measures rather than clinical risk measures.

The dashboard reporting logic remains separated from the machine-learning workflow. Power BI consumes the reusable PostgreSQL reporting views rather than independently recreating the underlying analytical aggregations.

---

## Interactive Streamlit Dashboard

**Status: Implemented and locally validated; public deployment pending.**

The project includes a five-page interactive research dashboard built
with Streamlit, Altair, and pandas. It presents validated descriptive
analytics and retrospective machine-learning evaluation results.

The application is designed for research communication and portfolio
demonstration. It is not a clinical decision-support system.

### Dashboard Pages

| Page | Analytical Content |
|---|---|
| Executive Overview | Development-cohort KPIs and 30-day readmission outcome distribution |
| Patient Demographics | Historical readmission patterns by age, gender, and race |
| Healthcare Utilization | Admission types, length of stay, prior utilization, and data completeness |
| Predictive Modeling | Optimized Random Forest performance on the independent held-out test partition |
| Model Evaluation | Patient-grouped HGB out-of-fold evaluation, calibration, bootstrap uncertainty, and subgroup robustness |

### Reporting Architecture

The public dashboard reads approved aggregate CSV and JSON reports
stored in `streamlit_app/data/`.

Descriptive reporting data is derived from the PostgreSQL reporting
views and represents the 86,547-encounter development cohort.

The application does not require a live PostgreSQL connection.

Raw encounter datasets, patient identifiers, individual prediction
records, trained model binaries, and database credentials are not
required to run the Streamlit dashboard.

### Model Evaluation Boundaries

The Random Forest results come from an independent held-out test
partition after configuration and threshold selection on development
data.

The Histogram Gradient Boosting results come from patient-grouped
out-of-fold validation within the development cohort. The model
family and hyperparameters were previously selected using that
cohort, so these are not fully independent generalization estimates.

Subgroup comparisons and bootstrap intervals describe retrospective
research findings. They do not establish causal effects or clinical
fairness.

### Validation Status

All five pages have passed local execution checks, and the primary
interactive selectors have passed 29 automated regression cases.

The application has also passed an external-working-directory launch
test and dependency-resolution checks for a specified Linux/Python
3.13 target.

A clean Linux runtime test, final publication review, and public
Streamlit Community Cloud deployment remain pending.

See `streamlit_app/DATA_CONTRACT.md` and
`streamlit_app/HGB_EVALUATION_CONTRACT.md` for detailed data and
evaluation requirements.

---

## Technology Stack

### Programming & Analysis

- Python
- Pandas
- NumPy
- Scikit-learn
- SciPy
- Matplotlib
- Jupyter

### Database & SQL

- PostgreSQL 18
- SQL
- PostgreSQL views
- Analytical schemas

### Machine Learning

- Logistic Regression
- Random Forest
- Histogram Gradient Boosting
- Hyperparameter optimization
- Threshold analysis
- Calibration analysis
- Patient-aware cross-validation
- Bootstrap uncertainty analysis

### Interpretability

- Permutation importance
- Grouped permutation importance
- Partial dependence
- Feature-family analysis
- Evidence triangulation

### Business Intelligence

- Power BI
- PostgreSQL reporting layer

### Interactive Analytics & Visualization

- Streamlit 1.66
- Altair 6.3
- pandas 3.0
- Interactive analytical dashboards
- Validated aggregate CSV/JSON reporting
- Streamlit Community Cloud (deployment pending)

### Development

- Git
- GitHub
- Visual Studio Code
- Python virtual environment

---

## Repository Structure

```text
healthcare-readmission-analytics/
│
├── dashboard/
│   └── Power BI dashboard assets
│
├── data/
│   ├── raw/
│   ├── interim/
│   └── processed/
│
├── docs/
│
├── models/
│   └── model artifacts
│
├── notebooks/
│   ├── 01_data_audit.ipynb
│   ├── 02_data_preprocessing.ipynb
│   ├── 03_exploratory_data_analysis.ipynb
│   ├── 04_feature_engineering.ipynb
│   ├── 05_baseline_modeling.ipynb
│   ├── 06_model_optimization.ipynb
│   ├── 07_model_validation.ipynb
│   └── 08_model_interpretability.ipynb
│
├── reports/
│   ├── model evaluation artifacts
│   ├── validation artifacts
│   ├── interpretability artifacts
│   └── figures
│
├── sql/
│   ├── 00_sql_data_contract.md
│   ├── 01_schema.sql
│   ├── 02_load_development_data.sql
│   ├── 03_readmission_kpis.sql
│   ├── 04_build_model_dataset.sql
│   └── 05_reporting_views.sql
│
├── streamlit_app/
│   ├── Executive_Overview.py
│   ├── pages/
│   │   ├── 1_Patient_Demographics.py
│   │   ├── 2_Healthcare_Utilization.py
│   │   ├── 3_Predictive_Modeling.py
│   │   └── 4_Model_Evaluation.py
│   ├── utils/
│   │   └── data_loader.py
│   ├── data/
│   │   ├── sql_exports/
│   │   └── model_exports/
│   ├── DATA_CONTRACT.md
│   ├── HGB_EVALUATION_CONTRACT.md
│   └── requirements.txt
│
├── src/
│
├── .gitignore
├── requirements.txt
├── requirements-lock.txt
└── README.md
```

---

## Reproducibility

The project was developed and audited using Python 3.13.6. The focused `requirements.txt` lists nine direct dependencies, while `requirements-lock.txt` preserves the original 111-package development-environment snapshot. Dependency resolution was verified on Windows with Python 3.13; clean installation on Linux and macOS has not been independently tested.

Create/activate the environment and install dependencies:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

The notebooks are intentionally maintained as a canonical sequence:

```text
01 → 02 → 03 → 04 → 05 → 06 → 07 → 08
```

Temporary execution copies, checkpoints, backups, and audit helper scripts are not part of the canonical notebook sequence.

### Streamlit Dashboard - Local Reproduction

The Streamlit dashboard uses its own dependency file: `streamlit_app/requirements.txt`. It runs independently of the full research environment and does not require a live PostgreSQL connection or local encounter-level data.

**Windows PowerShell (from repository root):**

```powershell
python -m venv .venv-streamlit
.\.venv-streamlit\Scripts\Activate.ps1
python -m pip install -r streamlit_app/requirements.txt
python -m streamlit run streamlit_app/Executive_Overview.py
```

**Linux/macOS (from repository root):**

```bash
python3 -m venv .venv-streamlit
source .venv-streamlit/bin/activate
python -m pip install -r streamlit_app/requirements.txt
python -m streamlit run streamlit_app/Executive_Overview.py
```

The application reads approved aggregate CSV and JSON reports from `streamlit_app/data/`. The root `requirements.txt` remains dedicated to the research workflow. Dependency resolution was verified for Windows and a specified Linux x86-64/Python 3.13 target; clean Linux execution and public deployment remain pending.

---

### PostgreSQL and Power BI Reproducibility

The SQL reporting layer was tested using PostgreSQL 18.

Create a PostgreSQL database named `healthcare_readmission` before running the SQL scripts.

The Python notebooks generate two development-cohort files required by PostgreSQL:

- `data/processed/train.csv`
- `data/processed/validation.csv`

These files are stored locally and are not included in the public Git repository.

Run the following commands from the repository root, in the order shown:

```powershell
psql -U postgres -d healthcare_readmission -X -v ON_ERROR_STOP=1 -f ".\sql\01_schema.sql"

psql -U postgres -d healthcare_readmission -X -v ON_ERROR_STOP=1 -v expected_db=healthcare_readmission -f ".\sql\02_load_development_data.sql"

psql -U postgres -d healthcare_readmission -X -v ON_ERROR_STOP=1 -v expected_db=healthcare_readmission -f ".\sql\04_build_model_dataset.sql"

psql -U postgres -d healthcare_readmission -X -v ON_ERROR_STOP=1 -f ".\sql\05_reporting_views.sql"
```

The required database-building sequence is:

**01 → 02 → 04 → 05**

`sql/03_readmission_kpis.sql` contains supplementary descriptive queries and can be executed after the development data is loaded.

The loader and analytical-table builder require the `expected_db` parameter and use transactions and data-quality checks.

The SQL and Power BI reporting layers analyze the 86,547-encounter development cohort. They do not load Notebook 07's locally generated prediction-level CSV.

#### Power BI Connection and Refresh

Open:

`dashboard/healthcare_readmission_dashboard.pbix`

Configure the PostgreSQL connection to the recreated `healthcare_readmission` database and refresh the dashboard.

The dashboard presents descriptive healthcare analytics, including readmission rates, demographics, utilization, length of stay, and data completeness. It does not display model-generated prediction probabilities.

---

## Evaluation Philosophy

This project emphasizes evaluation discipline over maximizing a single metric.

Important principles include:

1. **Separate development and held-out test data.**
2. **Do not use the held-out test set for iterative model development.**
3. **Use patient-aware validation when multiple encounters may belong to the same patient.**
4. **Evaluate more than ROC-AUC.**
5. **Examine calibration and probability quality.**
6. **Evaluate operating thresholds according to the intended use case.**
7. **Inspect subgroup robustness.**
8. **Treat model interpretation as associative rather than causal.**
9. **Document limitations rather than hiding them.**
10. **Keep reporting logic separate from machine-learning development logic.**

---

## Limitations

Several limitations should be considered when interpreting this project.

### Dataset limitations

The analysis is based on a historical U.S. hospital dataset covering 1999–2008.

Healthcare practices, coding conventions, treatment patterns, and patient populations may differ substantially from contemporary clinical environments.

### Observational data

The project identifies associations and predictive patterns.

It does not establish causal relationships.

### Generalization

The independent held-out test evaluation applies to the selected optimized Random Forest.

The later Histogram Gradient Boosting results are development-stage patient-aware validation results and should not be interpreted as an independent held-out generalization estimate.

### Subgroup robustness

Age-related performance heterogeneity represents an important limitation and warrants further investigation before any real-world deployment scenario.

### Clinical use

The model is a portfolio/research artifact and is **not a clinical decision-support system**.

No clinical recommendation should be made from its predictions.

---

## Key Takeaways

This project demonstrates an end-to-end workflow rather than a standalone machine-learning notebook.

The major components are:

- Data quality assessment
- Reproducible preprocessing
- Exploratory data analysis
- Feature engineering
- Baseline modeling
- Model optimization
- Independent held-out testing
- Patient-aware validation
- Calibration analysis
- Threshold optimization
- Subgroup robustness analysis
- Model interpretability
- Evidence triangulation
- PostgreSQL analytical modeling
- Reusable SQL reporting views
- Business-intelligence preparation

The most important methodological takeaway is that **model performance must be interpreted together with evaluation boundaries, uncertainty, subgroup behavior, and intended use**.

---

## Project Status

| Component | Status |
|---|---|
| Data audit | Complete |
| Preprocessing | Complete |
| EDA | Complete |
| Feature engineering | Complete |
| Baseline modeling | Complete |
| Model optimization | Complete |
| Held-out test evaluation | Complete |
| Patient-aware validation | Complete |
| Interpretability | Complete |
| PostgreSQL analytical layer | Complete |
| PostgreSQL reporting views | Complete |
| README / portfolio documentation | Complete |
| Power BI dashboard | Complete |

---

## Dataset Attribution & License

This project uses the **Diabetes 130-US Hospitals for Years 1999–2008** dataset from the UCI Machine Learning Repository.

**Dataset citation:** Clore, J., Cios, K., DeShazo, J., & Strack, B. (2014). *Diabetes 130-US Hospitals for Years 1999–2008* [Dataset]. UCI Machine Learning Repository. https://doi.org/10.24432/C5230J

**License:** Creative Commons Attribution 4.0 International (CC BY 4.0): https://creativecommons.org/licenses/by/4.0/

The original dataset contains 101,766 historical hospital encounters. This project applies preprocessing, feature engineering, partitioning, statistical analysis, and modeling to the source data. The public descriptive dashboard reports aggregate findings from the 86,547-encounter development cohort.

The dashboard also presents separately identified model-evaluation reports. Random Forest results originate from an independent held-out test partition, whereas Histogram Gradient Boosting results represent patient-grouped out-of-fold development validation.

This is an independent educational and professional portfolio project. The original dataset creators and UCI are credited; neither is represented as endorsing this analysis.

The dashboard is intended for retrospective research communication, not clinical decision-making.

For additional provenance, reporting restrictions, and publication safeguards, see `streamlit_app/DATA_CONTRACT.md`.

---

## Author

**Eric Amoh Adjei**

B.S. Data Science — University of Advancing Technology

Areas of interest:

- Data Analytics
- Data Science
- Machine Learning
- Business Intelligence
- Data Engineering
- Responsible AI
- Healthcare Analytics
