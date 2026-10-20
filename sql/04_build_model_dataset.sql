\set ON_ERROR_STOP on

\if :{?expected_db}
\else
    \echo 'STOP: Set expected_db before executing this script.'
    SELECT 1 / 0 AS missing_database_parameter;
\endif

SELECT current_database() = :'expected_db'
AS qa_database_confirmed \gset
\if :qa_database_confirmed
\else
    SELECT 1 / 0 AS wrong_database_guard;
\endif

BEGIN;

-- =============================================================================
-- 04. BUILD THE MODELING DATASET
-- =============================================================================
--
-- Purpose:
--   Create a controlled analytical dataset for the predictive modeling stage
--   of the healthcare readmission project.
--
-- Source:
--   staging.development_encounters
--
-- Development cohort:
--   71,520 training encounters
--   15,027 validation encounters
--   86,547 total development encounters
--
-- Target:
--   readmitted_30d
--   0 = no readmission within 30 days
--   1 = readmission within 30 days
--
-- Important:
--   The held-out test partition is intentionally excluded from this dataset.
--   It will remain untouched until final model evaluation.
--
-- Modeling philosophy:
--   This table contains a controlled subset of the validated source columns.
--   We do not automatically copy every available field into the model.
--
--   Candidate predictors are selected based on:
--     1. Predictive relevance.
--     2. Interpretability.
--     3. Data lineage.
--     4. Reasonable categorical cardinality.
--     5. Leakage prevention.
--
-- Leakage prevention:
--   readmitted is excluded because it contains the original three-category
--   readmission outcome (<30, >30, NO) and therefore directly represents the
--   outcome being modeled.
--
--   discharge_disposition_description is excluded from the initial predictive
--   feature set because discharge disposition is determined at the end of the
--   hospitalization and may contain information that would not be available
--   at the intended prediction point.
--
--   The diagnosis fields (diag_1, diag_2, diag_3) are excluded from this
--   initial model dataset because they require additional clinical grouping
--   and feature engineering before being introduced into the model.
--
--   Individual medication columns are excluded from this first model dataset
--   to keep the initial feature set interpretable and manageable. Broader
--   treatment indicators such as diabetesmed and change are retained.
--
-- Identifier handling:
--   encounter_id is retained for row-level traceability and is used as the
--   primary key, but it is NOT a machine-learning predictor.
--
--   patient_nbr is retained for auditability and future patient-level checks,
--   but it is NOT a machine-learning predictor because it is an identifier
--   rather than a meaningful clinical feature.
--
-- Missing-value handling:
--   Explicit source categories such as "Not recorded", "Unknown",
--   "Not Available", and "Not Mapped" are intentionally preserved.
--   They are source values rather than SQL NULLs and will be handled during
--   feature engineering.
--
-- Modeling workflow:
--   This SQL layer prepares the analytical dataset.
--   Python will later perform encoding, feature preparation, model training,
--   and model evaluation.
-- =============================================================================


-- =============================================================================
-- 1. RESET THE MODELING TABLE
-- =============================================================================

-- Remove an earlier version of the modeling table if it exists.
-- This makes the development workflow safely rerunnable.



-- =============================================================================
-- 2. CREATE THE MODELING DATASET
-- =============================================================================

-- Create the analytical modeling table from the validated development cohort.

-- QA_TRANSACTIONAL_ANALYTICAL_REBUILD
CREATE TABLE IF NOT EXISTS analytics.readmission_model_dataset AS
-- Select the target and approved candidate predictors.
SELECT

    -- Preserve the encounter identifier for traceability.
    -- This field will NOT be used as a machine-learning predictor.
    encounter_id,

    -- Preserve the patient identifier for auditability.
    -- This field will NOT be used as a machine-learning predictor.
    patient_nbr,

    -- Preserve the binary prediction target.
    -- 0 = no readmission within 30 days.
    -- 1 = readmission within 30 days.
    readmitted_30d,

    -- Preserve the original train/validation partition lineage.
    source_partition,


    -- -------------------------------------------------------------------------
    -- DEMOGRAPHIC FEATURES
    -- -------------------------------------------------------------------------

    -- Preserve the source race category.
    race,

    -- Preserve the source gender category.
    gender,

    -- Preserve the source age-band category.
    age,


    -- -------------------------------------------------------------------------
    -- ENCOUNTER AND UTILIZATION FEATURES
    -- -------------------------------------------------------------------------

    -- Number of days spent in the hospital during the encounter.
    time_in_hospital,

    -- Number of laboratory procedures performed.
    num_lab_procedures,

    -- Number of procedures performed.
    num_procedures,

    -- Number of medications recorded.
    num_medications,

    -- Number of outpatient visits recorded for the patient.
    number_outpatient,

    -- Number of emergency visits recorded for the patient.
    number_emergency,

    -- Number of prior inpatient visits recorded for the patient.
    number_inpatient,

    -- Number of diagnoses associated with the encounter.
    number_diagnoses,


    -- -------------------------------------------------------------------------
    -- CLINICAL AND TREATMENT FEATURES
    -- -------------------------------------------------------------------------

    -- Maximum glucose serum category.
    max_glu_serum,

    -- A1C result category.
    -- "Not recorded" is intentionally retained.
    a1cresult,

    -- Indicator showing whether diabetes medication was recorded.
    diabetesmed,

    -- Indicator describing whether medication was changed.
    change,


    -- -------------------------------------------------------------------------
    -- ENCOUNTER CONTEXT FEATURES
    -- -------------------------------------------------------------------------

    -- Description of the admission type.
    admission_type_description,

    -- Description of the source from which the patient was admitted.
    admission_source_description


-- Use only the validated development cohort.
FROM staging.development_encounters
WITH NO DATA;


-- QA_SCHEMA_COMPATIBILITY_CHECK
-- Derive expected column names, order, and types from the actual SELECT.

DROP TABLE IF EXISTS pg_temp.expected_analytical_schema;

CREATE TEMP TABLE expected_analytical_schema AS
-- Select the target and approved candidate predictors.
SELECT

    -- Preserve the encounter identifier for traceability.
    -- This field will NOT be used as a machine-learning predictor.
    encounter_id,

    -- Preserve the patient identifier for auditability.
    -- This field will NOT be used as a machine-learning predictor.
    patient_nbr,

    -- Preserve the binary prediction target.
    -- 0 = no readmission within 30 days.
    -- 1 = readmission within 30 days.
    readmitted_30d,

    -- Preserve the original train/validation partition lineage.
    source_partition,


    -- -------------------------------------------------------------------------
    -- DEMOGRAPHIC FEATURES
    -- -------------------------------------------------------------------------

    -- Preserve the source race category.
    race,

    -- Preserve the source gender category.
    gender,

    -- Preserve the source age-band category.
    age,


    -- -------------------------------------------------------------------------
    -- ENCOUNTER AND UTILIZATION FEATURES
    -- -------------------------------------------------------------------------

    -- Number of days spent in the hospital during the encounter.
    time_in_hospital,

    -- Number of laboratory procedures performed.
    num_lab_procedures,

    -- Number of procedures performed.
    num_procedures,

    -- Number of medications recorded.
    num_medications,

    -- Number of outpatient visits recorded for the patient.
    number_outpatient,

    -- Number of emergency visits recorded for the patient.
    number_emergency,

    -- Number of prior inpatient visits recorded for the patient.
    number_inpatient,

    -- Number of diagnoses associated with the encounter.
    number_diagnoses,


    -- -------------------------------------------------------------------------
    -- CLINICAL AND TREATMENT FEATURES
    -- -------------------------------------------------------------------------

    -- Maximum glucose serum category.
    max_glu_serum,

    -- A1C result category.
    -- "Not recorded" is intentionally retained.
    a1cresult,

    -- Indicator showing whether diabetes medication was recorded.
    diabetesmed,

    -- Indicator describing whether medication was changed.
    change,


    -- -------------------------------------------------------------------------
    -- ENCOUNTER CONTEXT FEATURES
    -- -------------------------------------------------------------------------

    -- Description of the admission type.
    admission_type_description,

    -- Description of the source from which the patient was admitted.
    admission_source_description


-- Use only the validated development cohort.
FROM staging.development_encounters
WITH NO DATA;

DO $$
DECLARE
    expected_definition JSONB;
    actual_definition JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_array(attnum, attname, atttypid, atttypmod)
        ORDER BY attnum
    )
    INTO expected_definition
    FROM pg_attribute
    WHERE attrelid = 'pg_temp.expected_analytical_schema'::regclass
      AND attnum > 0
      AND NOT attisdropped;

    SELECT jsonb_agg(
        jsonb_build_array(attnum, attname, atttypid, atttypmod)
        ORDER BY attnum
    )
    INTO actual_definition
    FROM pg_attribute
    WHERE attrelid =
        'analytics.readmission_model_dataset'::regclass
      AND attnum > 0
      AND NOT attisdropped;

    IF expected_definition IS DISTINCT FROM actual_definition THEN
        RAISE EXCEPTION
            'Analytical rebuild rejected: incompatible destination schema';
    END IF;
END
$$;

DROP TABLE expected_analytical_schema;

DELETE FROM analytics.readmission_model_dataset;

INSERT INTO analytics.readmission_model_dataset
-- Select the target and approved candidate predictors.
SELECT

    -- Preserve the encounter identifier for traceability.
    -- This field will NOT be used as a machine-learning predictor.
    encounter_id,

    -- Preserve the patient identifier for auditability.
    -- This field will NOT be used as a machine-learning predictor.
    patient_nbr,

    -- Preserve the binary prediction target.
    -- 0 = no readmission within 30 days.
    -- 1 = readmission within 30 days.
    readmitted_30d,

    -- Preserve the original train/validation partition lineage.
    source_partition,


    -- -------------------------------------------------------------------------
    -- DEMOGRAPHIC FEATURES
    -- -------------------------------------------------------------------------

    -- Preserve the source race category.
    race,

    -- Preserve the source gender category.
    gender,

    -- Preserve the source age-band category.
    age,


    -- -------------------------------------------------------------------------
    -- ENCOUNTER AND UTILIZATION FEATURES
    -- -------------------------------------------------------------------------

    -- Number of days spent in the hospital during the encounter.
    time_in_hospital,

    -- Number of laboratory procedures performed.
    num_lab_procedures,

    -- Number of procedures performed.
    num_procedures,

    -- Number of medications recorded.
    num_medications,

    -- Number of outpatient visits recorded for the patient.
    number_outpatient,

    -- Number of emergency visits recorded for the patient.
    number_emergency,

    -- Number of prior inpatient visits recorded for the patient.
    number_inpatient,

    -- Number of diagnoses associated with the encounter.
    number_diagnoses,


    -- -------------------------------------------------------------------------
    -- CLINICAL AND TREATMENT FEATURES
    -- -------------------------------------------------------------------------

    -- Maximum glucose serum category.
    max_glu_serum,

    -- A1C result category.
    -- "Not recorded" is intentionally retained.
    a1cresult,

    -- Indicator showing whether diabetes medication was recorded.
    diabetesmed,

    -- Indicator describing whether medication was changed.
    change,


    -- -------------------------------------------------------------------------
    -- ENCOUNTER CONTEXT FEATURES
    -- -------------------------------------------------------------------------

    -- Description of the admission type.
    admission_type_description,

    -- Description of the source from which the patient was admitted.
    admission_source_description


-- Use only the validated development cohort.
FROM staging.development_encounters;



-- =============================================================================
-- 3. ADD PRIMARY-KEY CONSTRAINT
-- =============================================================================

-- Define encounter_id as the unique row identifier for the modeling dataset.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'analytics.readmission_model_dataset'::regclass
          AND contype = 'p'
    ) THEN
        ALTER TABLE analytics.readmission_model_dataset
        ADD PRIMARY KEY (encounter_id);
    END IF;
END
$$;



-- =============================================================================
-- 4. VERIFY BASIC DATA INTEGRITY
-- =============================================================================

-- Confirm that the modeling dataset contains the expected number of rows,
-- unique encounters, and target classes.
SELECT

    -- Count every row in the modeling dataset.
    COUNT(*) AS total_rows,

    -- Confirm that every encounter identifier is unique.
    COUNT(DISTINCT encounter_id) AS unique_encounters,

    -- Count encounters with a 30-day readmission.
    SUM(readmitted_30d) AS readmitted_30d_encounters,

    -- Count encounters without a 30-day readmission.
    COUNT(*) - SUM(readmitted_30d)
        AS non_readmitted_30d_encounters

-- Read from the newly created modeling dataset.
FROM analytics.readmission_model_dataset;


-- =============================================================================
-- 5. VERIFY TARGET AND LINEAGE QUALITY
-- =============================================================================

-- Check for missing identifiers, missing target values, missing partition
-- lineage, and invalid binary target values.
SELECT

    -- Count rows where the target is NULL.
    COUNT(*) FILTER (
        WHERE readmitted_30d IS NULL
    ) AS null_readmitted_30d,

    -- Count rows where the encounter identifier is NULL.
    COUNT(*) FILTER (
        WHERE encounter_id IS NULL
    ) AS null_encounter_id,

    -- Count rows where the patient identifier is NULL.
    COUNT(*) FILTER (
        WHERE patient_nbr IS NULL
    ) AS null_patient_nbr,

    -- Count rows where the partition lineage is NULL.
    COUNT(*) FILTER (
        WHERE source_partition IS NULL
    ) AS null_source_partition,

    -- Count target values outside the permitted binary range.
    COUNT(*) FILTER (
        WHERE readmitted_30d NOT IN (0, 1)
    ) AS invalid_target_values

-- Read from the modeling dataset.
FROM analytics.readmission_model_dataset;


-- =============================================================================
-- 6. VERIFY TRAINING AND VALIDATION PARTITIONS
-- =============================================================================

-- Confirm that the modeling dataset preserves the original training and
-- validation partitions and their observed readmission rates.
SELECT

    -- Identify the source partition.
    source_partition,

    -- Count encounters in the partition.
    COUNT(*) AS total_encounters,

    -- Count 30-day readmissions in the partition.
    SUM(readmitted_30d) AS readmitted_30d_encounters,

    -- Calculate the observed readmission rate for the partition.
    ROUND(
        100.0 * SUM(readmitted_30d)
        / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate_pct

-- Read from the modeling dataset.
FROM analytics.readmission_model_dataset

-- Produce one row for each partition.
GROUP BY source_partition

-- Keep the partition order deterministic.
ORDER BY source_partition;


-- =============================================================================
-- 7. DOCUMENT THE MACHINE-LEARNING FEATURE SET
-- =============================================================================

-- The following columns are the candidate predictors that will be supplied
-- to the feature-engineering stage:
--
--   race
--   gender
--   age
--   time_in_hospital
--   num_lab_procedures
--   num_procedures
--   num_medications
--   number_outpatient
--   number_emergency
--   number_inpatient
--   number_diagnoses
--   max_glu_serum
--   a1cresult
--   diabetesmed
--   change
--   admission_type_description
--   admission_source_description
--
-- The following columns are retained for data management but are NOT model
-- predictors:
--
--   encounter_id
--   patient_nbr
--   source_partition
--
-- The following source variables are intentionally excluded from this initial
-- modeling dataset:
--
--   readmitted
--       Original three-category readmission outcome; excluded to prevent
--       direct target leakage.
--
--   discharge_disposition_description
--       Excluded because it is determined at the end of the hospitalization
--       and may not be available at the intended prediction point.
--
--   diag_1, diag_2, diag_3
--       Reserved for a later diagnosis-specific feature-engineering analysis.
--
--   Individual medication columns
--       Reserved from the initial feature set to keep the first model
--       interpretable and manageable.
--
-- This documentation intentionally describes these as modeling decisions
-- rather than universal rules. The feature set may be expanded later if
-- additional analysis justifies doing so.
-- =============================================================================






-- QA_ANALYTICAL_RECONCILIATION
-- Reject incomplete or inconsistent analytical datasets.

DO $$
DECLARE
    total_rows BIGINT;
    unique_patients BIGINT;
    training_rows BIGINT;
    validation_rows BIGINT;
    positive_rows BIGINT;
    duplicate_encounters BIGINT;
    overlapping_patients BIGINT;
BEGIN
    SELECT
        COUNT(*),
        COUNT(DISTINCT patient_nbr),
        COUNT(*) FILTER (WHERE source_partition = 'train'),
        COUNT(*) FILTER (WHERE source_partition = 'validation'),
        COUNT(*) FILTER (WHERE readmitted_30d = 1),
        COUNT(*) - COUNT(DISTINCT encounter_id)
    INTO
        total_rows,
        unique_patients,
        training_rows,
        validation_rows,
        positive_rows,
        duplicate_encounters
    FROM analytics.readmission_model_dataset;

    SELECT COUNT(*)
    INTO overlapping_patients
    FROM (
        SELECT patient_nbr
        FROM analytics.readmission_model_dataset
        GROUP BY patient_nbr
        HAVING COUNT(DISTINCT source_partition) > 1
    ) overlap_check;

    IF total_rows <> 86547
       OR unique_patients <> 60790
       OR training_rows <> 71520
       OR validation_rows <> 15027
       OR positive_rows <> 9677
       OR duplicate_encounters <> 0
       OR overlapping_patients <> 0
    THEN
        RAISE EXCEPTION
            'Analytical reconciliation failed: rows=%, patients=%, train=%, validation=%, positives=%, duplicates=%, overlap=%',
            total_rows, unique_patients, training_rows,
            validation_rows, positive_rows,
            duplicate_encounters, overlapping_patients;
    END IF;

    RAISE NOTICE
        'Analytical reconciliation passed: % encounters, % patients',
        total_rows, unique_patients;
END
$$;

-- Complete analytical rebuild only after all SQL succeeds.
COMMIT;
