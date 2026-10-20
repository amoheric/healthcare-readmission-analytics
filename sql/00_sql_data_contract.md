# SQL Data Contract — Healthcare Readmission Analytics

## 1. Purpose

This document defines the data boundaries, table grain, keys, analytical
population, and modeling safeguards for the PostgreSQL and BI layer of the
Healthcare Readmission Analytics project.

The SQL layer is designed to demonstrate relational database design,
analytical SQL, data-quality validation, reusable reporting views, and
business-intelligence preparation without changing the completed machine
learning workflow.


## 2. PostgreSQL Database

Database name:

`healthcare_readmission`

Primary SQL engine:

`PostgreSQL 18`

Development environment:

`Visual Studio Code`

Implemented BI layer:

`Power BI`


## 3. Analytical Grain

The primary analytical table uses:

**One row = one hospital encounter.**

The encounter identifier will therefore serve as the primary encounter-level
key.

Encounter-level key:

`encounter_id`

A patient may appear in multiple encounters, so:

`patient_nbr`

is a patient identifier and must NOT be treated as an encounter-level primary
key.


## 4. Development Cohort

The SQL and Power BI descriptive analytics layer uses the existing
machine-learning development cohort:

- Training encounters
- Validation encounters

These partitions contain 86,547 encounters in total.

The separately reserved test partition is excluded from the SQL and
Power BI development workflow. Descriptive analysis and dashboard
construction therefore use development-cohort records only.


## 5. Held-Out Test Boundary

The held-out test partition must NOT be:

- loaded into the development SQL analytical tables;
- queried for KPI development;
- used to choose dashboard metrics;
- used to revise features;
- used to select model thresholds;
- used to select models or hyperparameters;
- used to develop model interpretations.

This preserves the separation between development analytics and
independent test evaluation. The Random Forest has a documented held-out
test result; HGB results presented in this project come from patient-grouped
out-of-fold validation and must not be described as an independent test.

If the test partition is intentionally evaluated later, that evaluation must
be explicitly documented as a separate project stage.


## 6. Outcome Definition

Primary analytical outcome:

`readmitted_30d`

Interpretation:

- `1` = hospital readmission within 30 days
- `0` = no hospital readmission within 30 days

The original source outcome:

`readmitted`

may remain available for lineage or auditing where appropriate, but it must
not be confused with the binary modeling target.


## 7. Identifier Rules

### encounter_id

Purpose:

Unique identifier for a hospital encounter.

Expected SQL role:

Primary key of the encounter-level analytical table.

### patient_nbr

Purpose:

Identifier linking multiple encounters belonging to the same patient.

Expected SQL role:

Patient-level grouping and repeated-encounter analysis.

It must not be used as a model predictor.


## 8. Model-Linked Predictions

Notebook 07 generates patient-aware out-of-fold (OOF) predictions
for the machine-learning validation workflow.

Local output:

`reports/notebook07_oof_predictions.csv`

The file contains encounter-level prediction records and is retained
locally rather than tracked in the published Git repository.

Its fields include `encounter_id`, `patient_nbr`,
`source_partition`, `fold`, `readmitted_30d`, and
`oof_probability`.

The current PostgreSQL analytical tables and Power BI dashboard
do not load or join this prediction file. Model-performance and
prediction-based findings are reported separately through the
notebooks and evaluation artifacts.

Consequently, the published dashboard must not be described
as displaying model-predicted readmission probabilities.


## 9. Separation of Analytical Concepts

The project distinguishes three types of evidence:

### Observed historical outcomes

The PostgreSQL and Power BI layer reports descriptive measures,
including readmission rates, encounter counts, demographic
distributions, length of stay, and utilization patterns.

### Model estimates

Notebook 07 evaluates patient-aware OOF predictions. These
probabilities belong to the machine-learning validation workflow
and are not currently integrated into the SQL reporting views.

### Predictive relationships

Notebook 08 examines model interpretation and feature-related
patterns. Such relationships are predictive associations, not
established causal effects.


## 10. Implemented PostgreSQL Layers

The database uses three logical schemas.

### `staging`

`staging.development_encounters` stores validated encounter-level
development data. The loading workflow also uses a raw staging
table for input validation before inserting typed records.

### `analytics`

`analytics.readmission_model_dataset` provides a reusable,
encounter-level analytical table for SQL queries and reporting.

### `reporting`

Nine reporting views expose descriptive healthcare measures
for Power BI and other analytical consumers.

The version-controlled SQL scripts define the database objects
and reporting logic.


## 11. Implemented SQL Quality Controls

The SQL pipeline includes checks for:

- expected development-cohort and partition row counts;
- encounter identifier completeness and uniqueness;
- patient identifier completeness;
- binary outcome validity and expected outcome counts;
- numeric input validity and selected value ranges;
- duplicate encounters and train/validation patient overlap;
- analytical-table schema consistency during rebuilds;
- reconciliation between staging and analytical records.

The loader and analytical-table builder include explicit
database-name safeguards and transactional execution.

The SQL reporting layer does not currently implement OOF
prediction coverage or encounter-to-prediction join checks,
because prediction records are not loaded into that layer.


## 12. Reproducibility Rule

Important database objects must be created from version-controlled `.sql`
files in the repository.

Interactive `psql` commands may be used for learning, inspection, and
debugging, but they must not become the only record of important database
logic.


## 13. Documentation Standard

SQL files will use:

1. file-level purpose headers;
2. section comments;
3. plain-English comments for important logic;
4. descriptive table, column, CTE, and view names;
5. comments explaining non-obvious PostgreSQL-specific syntax.

Comments should explain WHY logic exists when possible rather than merely
repeat obvious SQL syntax.


## 14. Current Methodological Boundary

The PostgreSQL and Power BI phase extends the analytical
project with descriptive reporting.

It does NOT:

- retrain or independently test the HGB model;
- change model hyperparameters or features;
- select a new model threshold;
- replace Notebook 07 validation;
- replace Notebook 08 interpretability;
- integrate encounter-level model predictions into SQL reporting;
- establish causal effects;
- establish external validation;
- establish clinical deployment readiness.

The Random Forest held-out test and HGB patient-grouped OOF
results are separate evaluation results and must not be
presented as interchangeable evidence.
