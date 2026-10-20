-- =============================================================================
-- Healthcare Readmission Analytics
-- File: 05_reporting_views.sql
--
-- Purpose:
--   Create reusable PostgreSQL reporting views for the BI/dashboard layer.
--
--   These views transform the validated analytical/model dataset into
--   presentation-ready summaries that can be consumed by Power BI or another
--   reporting tool.
--
-- Source:
--   analytics.readmission_model_dataset
--
-- Development cohort:
--   86,547 training + validation encounters
--
-- Important evaluation boundary:
--   The held-out test partition is not included in this reporting layer.
--   These views operate only on the development cohort that was intentionally
--   used for development-stage analytics and reporting.
--
-- Machine-learning boundary:
--   These views are descriptive reporting objects.
--   They do not retrain, optimize, recalibrate, or modify any machine-learning
--   model.
--
-- Architecture:
--
--   Source data
--       |
--       v
--   Data audit / preprocessing / feature engineering
--       |
--       v
--   analytics.readmission_model_dataset
--       |
--       v
--   reporting views
--       |
--       v
--   Power BI / BI dashboard
--
-- Why use PostgreSQL views?
--   A database view provides a reusable SQL definition for an analytical
--   result. Instead of rebuilding the same aggregation every time a dashboard
--   needs a metric, Power BI can consume a named reporting view.
--
--   This also keeps the reporting logic visible, reproducible, and separate
--   from the machine-learning notebooks.
--
-- Naming convention:
--   "vw_" identifies a reporting view.
--   The remainder of the name describes the analytical subject of the view.
--
-- Example:
--   reporting.vw_readmission_kpi
--       -> reporting schema
--       -> vw_ = view
--       -> readmission_kpi = subject/purpose
--
-- SQL concepts used throughout this file:
--   COUNT(*)     = counts rows/encounters
--   SUM(binary)  = counts positive observations when the binary field is
--                  encoded as 0/1
--   AVG(...)     = calculates an arithmetic mean
--   GROUP BY     = creates one summary row for each category
--   ROUND(...)   = controls numeric display precision
--   NULLIF(...,0)= prevents division-by-zero errors
--   CASE         = creates a derived categorical flag
--
-- Interpretation caution:
--   These are observational/descriptive summaries. Differences between groups
--   should not automatically be interpreted as causal effects.
-- =============================================================================


-- =============================================================================
-- 1. CREATE REPORTING SCHEMA
-- =============================================================================
--
-- Analytical purpose:
--   Create a dedicated database namespace for BI/reporting objects.
--
-- Why a separate schema?
--   Separating "reporting" from "staging" and "analytics" makes the database
--   architecture easier to understand:
--
--       staging   -> imported/controlled source data
--       analytics -> analytical/modeling dataset
--       reporting -> reusable dashboard/reporting outputs
--
-- IF NOT EXISTS:
--   Prevents an error if the reporting schema has already been created.
--   Running this statement again is therefore safe.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS reporting;


-- =============================================================================
-- 2. OVERALL READMISSION KPI
-- =============================================================================
--
-- Analytical question:
--   Across the development cohort, how many encounters occurred, how many
--   resulted in a 30-day readmission, and what percentage resulted in a
--   30-day readmission?
--
-- Why this view exists:
--   This is the primary high-level KPI for the project and is suitable for
--   dashboard cards or executive-level reporting.
--
-- Source grain:
--   One row in analytics.readmission_model_dataset represents one encounter.
--
-- Key calculation:
--   readmitted_30d is a binary target:
--       1 = readmitted within 30 days
--       0 = not readmitted within 30 days
--
--   Therefore:
--       COUNT(*)                 = total encounters
--       SUM(readmitted_30d)      = 30-day readmitted encounters
--       COUNT(*) - SUM(...)      = non-readmitted encounters
--
-- Readmission rate:
--       readmitted encounters / total encounters * 100
--
-- NULLIF:
--   NULLIF(COUNT(*), 0) prevents a division-by-zero error if the source table
--   were ever empty.
--
-- Portfolio/dashboard use:
--   This view can be connected to Power BI and used for KPI cards.
--
-- Expected development-cohort result:
--   86,547 total encounters
--    9,677 30-day readmissions
--      11.18% observed 30-day readmission rate
-- =============================================================================

CREATE OR REPLACE VIEW reporting.vw_readmission_kpi AS
SELECT
    COUNT(*) AS total_encounters,
    SUM(readmitted_30d) AS readmitted_30d_encounters,
    COUNT(*) - SUM(readmitted_30d) AS non_readmitted_30d_encounters,
    ROUND(
        100.0 * SUM(readmitted_30d)
        / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate_pct
FROM analytics.readmission_model_dataset;


-- =============================================================================
-- 3. READMISSION BY DEVELOPMENT PARTITION
-- =============================================================================
--
-- Analytical question:
--   Is the observed 30-day readmission rate reasonably consistent between
--   the training and validation portions of the development cohort?
--
-- Why this view exists:
--   A large difference in target prevalence between development partitions
--   could indicate a data-distribution issue that is important to understand
--   before interpreting downstream modeling results.
--
-- GROUP BY:
--   source_partition creates one summary row for each development partition.
--
-- Expected categories:
--       train
--       validation
--
-- Important:
--   This is a development-data diagnostic, not a model-performance metric.
--   It describes the target distribution in each partition.
--
-- Portfolio/dashboard use:
--   Useful for demonstrating that the project maintains visibility into
--   partition-level data characteristics.
-- =============================================================================

CREATE OR REPLACE VIEW reporting.vw_readmission_by_partition AS
SELECT
    source_partition,
    COUNT(*) AS total_encounters,
    SUM(readmitted_30d) AS readmitted_30d_encounters,
    ROUND(
        100.0 * SUM(readmitted_30d)
        / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate_pct
FROM analytics.readmission_model_dataset
GROUP BY source_partition
ORDER BY source_partition;


-- =============================================================================
-- 4. READMISSION BY AGE GROUP
-- =============================================================================
--
-- Analytical question:
--   Does the observed 30-day readmission rate differ across the age groups
--   represented in the development cohort?
--
-- Why this view exists:
--   Age is a useful descriptive population characteristic. Examining the
--   outcome across age groups helps identify patterns and potential
--   heterogeneity that may deserve additional investigation.
--
-- What this view returns:
--   For each age category:
--       - total encounters
--       - 30-day readmissions
--       - observed readmission rate
--       - volume flag
--
-- volume_flag:
--   A group containing fewer than 100 encounters is labeled "Small sample".
--   This is a simple warning that a percentage calculated from a small number
--   of observations may be less stable and should not be overinterpreted.
--
-- Important interpretation:
--   An observed difference between age groups does not establish that age
--   causes readmission.
--
-- Portfolio/dashboard use:
--   Suitable for a Power BI bar/column chart comparing readmission rates
--   across age groups.
-- =============================================================================

CREATE OR REPLACE VIEW reporting.vw_readmission_by_age AS
SELECT
    age AS age_group,
    COUNT(*) AS total_encounters,
    SUM(readmitted_30d) AS readmitted_30d_encounters,
    ROUND(
        100.0 * SUM(readmitted_30d)
        / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate_pct,
    CASE
        WHEN COUNT(*) < 100 THEN 'Small sample'
        ELSE 'Sufficient volume'
    END AS volume_flag
FROM analytics.readmission_model_dataset
GROUP BY age
ORDER BY age;


-- =============================================================================
-- 5. READMISSION BY GENDER
-- =============================================================================
--
-- Analytical question:
--   How does the observed 30-day readmission rate compare across the gender
--   categories represented in the development cohort?
--
-- Why this view exists:
--   Gender is included as a descriptive population dimension and can be used
--   to inspect whether the observed outcome distribution differs across groups.
--
-- volume_flag:
--   Groups with fewer than 100 encounters are labeled "Small sample".
--   This provides a simple volume warning for downstream reporting.
--
-- Important interpretation:
--   This view describes observed differences. It does not establish causation
--   or prove that gender itself produces a difference in readmission risk.
--
-- Portfolio/dashboard use:
--   Suitable for a grouped comparison visual in Power BI.
-- =============================================================================

CREATE OR REPLACE VIEW reporting.vw_readmission_by_gender AS
SELECT
    gender,
    COUNT(*) AS total_encounters,
    SUM(readmitted_30d) AS readmitted_30d_encounters,
    ROUND(
        100.0 * SUM(readmitted_30d)
        / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate_pct,
    CASE
        WHEN COUNT(*) < 100 THEN 'Small sample'
        ELSE 'Sufficient volume'
    END AS volume_flag
FROM analytics.readmission_model_dataset
GROUP BY gender
ORDER BY total_encounters DESC;


-- =============================================================================
-- 6. READMISSION BY RACE
-- =============================================================================
--
-- Analytical question:
--   How does the observed 30-day readmission rate vary across the race
--   categories represented in the development cohort?
--
-- Why this view exists:
--   Race is included as a descriptive population dimension and supports
--   responsible examination of outcome distributions across demographic
--   groups.
--
-- volume_flag:
--   Groups with fewer than 100 encounters are labeled "Low volume".
--   Larger groups are labeled "Higher volume".
--
-- Important interpretation:
--   Differences in observed rates should not be interpreted as causal.
--   Race is being used here as a descriptive analysis dimension, not as proof
--   of a biological or causal mechanism.
--
-- Responsible reporting:
--   Small groups should be interpreted cautiously because rate estimates can
--   be less stable when based on relatively few encounters.
--
-- Portfolio/dashboard use:
--   This view supports demographic outcome analysis in the BI layer.
-- =============================================================================

CREATE OR REPLACE VIEW reporting.vw_readmission_by_race AS
SELECT
    race,
    COUNT(*) AS total_encounters,
    SUM(readmitted_30d) AS readmitted_30d_encounters,
    ROUND(
        100.0 * SUM(readmitted_30d)
        / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate_pct,
    CASE
        WHEN COUNT(*) < 100 THEN 'Low volume'
        ELSE 'Higher volume'
    END AS volume_flag
FROM analytics.readmission_model_dataset
GROUP BY race
ORDER BY total_encounters DESC;


-- =============================================================================
-- 7. READMISSION BY ADMISSION TYPE
-- =============================================================================
--
-- Analytical question:
--   How does the observed 30-day readmission rate differ by admission type?
--
-- Why this view exists:
--   Admission type provides operational context for the encounter. Comparing
--   observed rates across admission categories can help identify areas for
--   further descriptive investigation.
--
-- GROUP BY:
--   Each distinct admission_type_description becomes one result row.
--
-- Examples represented in the source:
--       Emergency
--       Elective
--       Urgent
--       Unknown
--       Not Available
--       Not Mapped
--       Trauma Center
--       Newborn
--
-- Important:
--   "Unknown", "Not Available", and "Not Mapped" are retained as categories
--   rather than silently being treated as equivalent to a valid admission
--   category.
--
-- Portfolio/dashboard use:
--   Suitable for a horizontal bar chart or table in Power BI.
-- =============================================================================

CREATE OR REPLACE VIEW reporting.vw_readmission_by_admission_type AS
SELECT
    admission_type_description,
    COUNT(*) AS total_encounters,
    SUM(readmitted_30d) AS readmitted_30d_encounters,
    ROUND(
        100.0 * SUM(readmitted_30d)
        / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate_pct
FROM analytics.readmission_model_dataset
GROUP BY admission_type_description
ORDER BY total_encounters DESC;


-- =============================================================================
-- 8. READMISSION BY LENGTH OF STAY
-- =============================================================================
--
-- Analytical question:
--   How does the observed 30-day readmission rate vary with hospital
--   length of stay?
--
-- Why this view exists:
--   Length of stay is an important operational utilization measure.
--   Summarizing readmission outcomes by stay duration allows the dashboard
--   to show the relationship observed in the development data.
--
-- Output:
--   One row represents one recorded length-of-stay value.
--
-- Important interpretation:
--   This is descriptive analysis. A higher readmission rate at a particular
--   length of stay does not demonstrate that length of stay causes readmission.
--
-- Portfolio/dashboard use:
--   Well suited to a line or column chart showing observed readmission rate
--   across hospital-stay durations.
-- =============================================================================

CREATE OR REPLACE VIEW reporting.vw_readmission_by_los AS
SELECT
    time_in_hospital AS length_of_stay_days,
    COUNT(*) AS total_encounters,
    SUM(readmitted_30d) AS readmitted_30d_encounters,
    ROUND(
        100.0 * SUM(readmitted_30d)
        / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate_pct
FROM analytics.readmission_model_dataset
GROUP BY time_in_hospital
ORDER BY time_in_hospital;


-- =============================================================================
-- 9. UTILIZATION BY READMISSION OUTCOME
-- =============================================================================
--
-- Analytical question:
--   How do average utilization characteristics differ between encounters
--   with and without a 30-day readmission?
--
-- Why this view exists:
--   Instead of examining only the outcome rate, this view compares several
--   encounter-level utilization measures between the two outcome groups.
--
-- Measures included:
--       average length of stay
--       average laboratory procedures
--       average procedures
--       average medications
--       average outpatient visits
--       average emergency visits
--       average inpatient visits
--       average diagnoses
--
-- GROUP BY:
--   readmitted_30d creates two expected result groups:
--       0 = no 30-day readmission
--       1 = 30-day readmission
--
-- Important interpretation:
--   Differences in group averages are descriptive associations. They should
--   not be interpreted as evidence that one utilization measure causes
--   readmission.
--
-- Portfolio/dashboard use:
--   This view can support side-by-side KPI cards, tables, or comparison
--   visuals in Power BI.
-- =============================================================================

CREATE OR REPLACE VIEW reporting.vw_utilization_by_outcome AS
SELECT
    readmitted_30d AS readmitted_within_30_days,
    COUNT(*) AS total_encounters,
    ROUND(AVG(time_in_hospital), 2) AS avg_length_of_stay,
    ROUND(AVG(num_lab_procedures), 2) AS avg_lab_procedures,
    ROUND(AVG(num_procedures), 2) AS avg_procedures,
    ROUND(AVG(num_medications), 2) AS avg_medications,
    ROUND(AVG(number_outpatient), 2) AS avg_outpatient_visits,
    ROUND(AVG(number_emergency), 2) AS avg_emergency_visits,
    ROUND(AVG(number_inpatient), 2) AS avg_inpatient_visits,
    ROUND(AVG(number_diagnoses), 2) AS avg_diagnoses
FROM analytics.readmission_model_dataset
GROUP BY readmitted_30d
ORDER BY readmitted_30d;


-- =============================================================================
-- 10. DATA COMPLETENESS
-- =============================================================================
--
-- Analytical question:
--   How frequently are selected clinical/demographic fields represented by
--   explicit "not recorded" or "unknown" categories?
--
-- Why this view exists:
--   Data completeness is important when interpreting both descriptive
--   analytics and machine-learning results. Missingness or unavailable values
--   can affect how confidently a variable should be interpreted.
--
-- Important data-handling principle:
--   The project preserves source categories such as "Not recorded" and
--   "Unknown" rather than automatically converting them to SQL NULL.
--
-- What is measured:
--       a1cresult = 'Not recorded'
--       max_glu_serum = 'Not recorded'
--       race = 'Unknown'
--
-- Calculation:
--   COUNT(*) FILTER (WHERE condition) counts only rows satisfying the
--   specified condition.
--
--   Dividing that count by COUNT(*) produces the proportion of the complete
--   development cohort represented by the category.
--
--   Multiplication by 100 converts the proportion to a percentage.
--
-- Why NULLIF is used:
--   NULLIF(COUNT(*), 0) prevents division by zero if the source table is empty.
--
-- Portfolio/dashboard use:
--   These percentages can be displayed as data-quality indicators in Power BI.
--
-- Important:
--   This view reports selected completeness indicators. It is not intended
--   to represent every possible missingness pattern in the source dataset.
-- =============================================================================

CREATE OR REPLACE VIEW reporting.vw_data_completeness AS
SELECT
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE a1cresult = 'Not recorded'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS a1c_not_recorded_pct,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE max_glu_serum = 'Not recorded'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS max_glucose_not_recorded_pct,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE race = 'Unknown'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS race_unknown_pct
FROM analytics.readmission_model_dataset;