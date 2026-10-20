\set ON_ERROR_STOP on

-- DATABASE SAFETY GUARD
-- The caller must explicitly supply expected_db.
-- Execution stops if the connected database does not match.
--
-- Example:
-- psql -U postgres -d healthcare_readmission -X -v ON_ERROR_STOP=1 -v expected_db=healthcare_readmission -f sql/02_load_development_data.sql

\if :{?expected_db}
\else
    \echo 'STOP: Set expected_db before executing this script.'
    SELECT 1 / 0 AS missing_database_parameter;
\endif

SELECT current_database() = :'expected_db'
AS qa_database_confirmed \gset
\if :qa_database_confirmed
\else
    SELECT 1 / 0 AS qa_guard_failure;
\endif

BEGIN;


-- QA_VALIDATE_RAW_DATA
CREATE OR REPLACE FUNCTION pg_temp.validate_raw_data(
    expected_rows BIGINT,
    partition_name TEXT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    actual_rows BIGINT;
BEGIN
    SELECT COUNT(*) INTO actual_rows
    FROM staging.development_encounters_raw;

    IF actual_rows <> expected_rows THEN
        RAISE EXCEPTION
            'Data validation failed for %: expected % rows, found %',
            partition_name, expected_rows, actual_rows;
    END IF;


    IF EXISTS (
        SELECT 1
        FROM staging.development_encounters_raw
        WHERE encounter_id IS NULL
           OR encounter_id !~ '^[0-9]+$'
           OR NOT pg_input_is_valid(encounter_id, 'bigint')
    ) THEN
        RAISE EXCEPTION
            'Data validation failed: invalid numeric field encounter_id';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM staging.development_encounters_raw
        WHERE patient_nbr IS NULL
           OR patient_nbr !~ '^[0-9]+$'
           OR NOT pg_input_is_valid(patient_nbr, 'bigint')
    ) THEN
        RAISE EXCEPTION
            'Data validation failed: invalid numeric field patient_nbr';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM staging.development_encounters_raw
        WHERE readmitted_30d IS NULL
           OR readmitted_30d !~ '^[0-9]+$'
           OR NOT pg_input_is_valid(readmitted_30d, 'smallint')
    ) THEN
        RAISE EXCEPTION
            'Data validation failed: invalid numeric field readmitted_30d';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM staging.development_encounters_raw
        WHERE time_in_hospital IS NULL
           OR time_in_hospital !~ '^[0-9]+$'
           OR NOT pg_input_is_valid(time_in_hospital, 'integer')
    ) THEN
        RAISE EXCEPTION
            'Data validation failed: invalid numeric field time_in_hospital';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM staging.development_encounters_raw
        WHERE num_lab_procedures IS NULL
           OR num_lab_procedures !~ '^[0-9]+$'
           OR NOT pg_input_is_valid(num_lab_procedures, 'integer')
    ) THEN
        RAISE EXCEPTION
            'Data validation failed: invalid numeric field num_lab_procedures';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM staging.development_encounters_raw
        WHERE num_procedures IS NULL
           OR num_procedures !~ '^[0-9]+$'
           OR NOT pg_input_is_valid(num_procedures, 'integer')
    ) THEN
        RAISE EXCEPTION
            'Data validation failed: invalid numeric field num_procedures';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM staging.development_encounters_raw
        WHERE num_medications IS NULL
           OR num_medications !~ '^[0-9]+$'
           OR NOT pg_input_is_valid(num_medications, 'integer')
    ) THEN
        RAISE EXCEPTION
            'Data validation failed: invalid numeric field num_medications';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM staging.development_encounters_raw
        WHERE number_outpatient IS NULL
           OR number_outpatient !~ '^[0-9]+$'
           OR NOT pg_input_is_valid(number_outpatient, 'integer')
    ) THEN
        RAISE EXCEPTION
            'Data validation failed: invalid numeric field number_outpatient';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM staging.development_encounters_raw
        WHERE number_emergency IS NULL
           OR number_emergency !~ '^[0-9]+$'
           OR NOT pg_input_is_valid(number_emergency, 'integer')
    ) THEN
        RAISE EXCEPTION
            'Data validation failed: invalid numeric field number_emergency';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM staging.development_encounters_raw
        WHERE number_inpatient IS NULL
           OR number_inpatient !~ '^[0-9]+$'
           OR NOT pg_input_is_valid(number_inpatient, 'integer')
    ) THEN
        RAISE EXCEPTION
            'Data validation failed: invalid numeric field number_inpatient';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM staging.development_encounters_raw
        WHERE number_diagnoses IS NULL
           OR number_diagnoses !~ '^[0-9]+$'
           OR NOT pg_input_is_valid(number_diagnoses, 'integer')
    ) THEN
        RAISE EXCEPTION
            'Data validation failed: invalid numeric field number_diagnoses';
    END IF;


    -- QA_RAW_ENCOUNTER_UNIQUENESS
    IF EXISTS (
        SELECT 1
        FROM staging.development_encounters_raw
        GROUP BY encounter_id
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION
            'Data validation failed for %: duplicate encounter IDs',
            partition_name;
    END IF;


    -- QA_SEMANTIC_VALIDATION
    -- The earlier numeric checks must pass before these casts execute.

    IF EXISTS (
        SELECT 1
        FROM staging.development_encounters_raw
        WHERE encounter_id::BIGINT < 1
           OR patient_nbr::BIGINT < 1
           OR readmitted_30d::SMALLINT NOT IN (0, 1)
           OR time_in_hospital::INTEGER < 1
           OR num_lab_procedures::INTEGER < 0
           OR num_procedures::INTEGER < 0
           OR num_medications::INTEGER < 0
           OR number_outpatient::INTEGER < 0
           OR number_emergency::INTEGER < 0
           OR number_inpatient::INTEGER < 0
           OR number_diagnoses::INTEGER < 1
    ) THEN
        RAISE EXCEPTION
            'Data validation failed for %: numeric domain violation',
            partition_name;
    END IF;


    IF EXISTS (
        SELECT 1
        FROM staging.development_encounters_raw
        WHERE readmitted IS NULL
           OR readmitted NOT IN ('<30', '>30', 'NO')
           OR readmitted_30d IS DISTINCT FROM
              CASE WHEN readmitted = '<30' THEN '1' ELSE '0' END
    ) THEN
        RAISE EXCEPTION
            'Data validation failed: readmission target mapping';
    END IF;
END;
$$;


-- =============================================================================
-- Healthcare Readmission Analytics
-- File: 02_load_development_data.sql
--
-- Purpose:
--   Load the existing training and validation encounter data into PostgreSQL.
--
-- Development-data boundary:
--   Only train.csv and validation.csv are loaded by this script.
--   test.csv is deliberately excluded from the SQL/BI development workflow.
--
-- Expected source rows:
--   Training:    71,520 encounters
--   Validation:  15,027 encounters
--   Total:       86,547 encounters
--
-- Target table:
--   staging.development_encounters
--
-- Grain:
--   One row = one hospital encounter.
--
-- Important:
--   The CSV files contain several column names that differ from our SQL naming
--   convention. For example:
--
--       CSV                         PostgreSQL
--       -------------------------   -------------------------
--       A1Cresult                   a1cresult
--       diabetesMed                 diabetesmed
--       glyburide-metformin         glyburide_metformin
--       glipizide-metformin         glipizide_metformin
--       glimepiride-pioglitazone    glimepiride_pioglitazone
--       metformin-rosiglitazone     metformin_rosiglitazone
--       metformin-pioglitazone      metformin_pioglitazone
--
--   Because source_partition does not exist in the original CSV files, the
--   loading workflow must explicitly add either 'train' or 'validation'.
--
--   Data will be validated after loading before it is promoted from the
--   staging layer to the analytics layer.
-- =============================================================================

-- =============================================================================
-- 1. CREATE THE RAW CSV IMPORT TABLE
-- =============================================================================

-- This table mirrors the 48-column structure of the processed CSV files.
-- It is used only as a controlled landing area before data is inserted into
-- staging.development_encounters.
--
-- Most columns are stored as TEXT here intentionally. PostgreSQL will validate
-- and convert the required numeric fields when we later insert the records into
-- the strongly typed staging table.
--
-- This two-step design helps separate:
--   1. File ingestion
--   2. Data-type and integrity validation

CREATE TABLE IF NOT EXISTS staging.development_encounters_raw (
    encounter_id TEXT,
    patient_nbr TEXT,
    readmitted TEXT,
    readmitted_30d TEXT,
    race TEXT,
    gender TEXT,
    age TEXT,
    time_in_hospital TEXT,
    payer_code TEXT,
    medical_specialty TEXT,
    num_lab_procedures TEXT,
    num_procedures TEXT,
    num_medications TEXT,
    number_outpatient TEXT,
    number_emergency TEXT,
    number_inpatient TEXT,
    diag_1 TEXT,
    diag_2 TEXT,
    diag_3 TEXT,
    number_diagnoses TEXT,
    max_glu_serum TEXT,
    a1cresult TEXT,
    metformin TEXT,
    repaglinide TEXT,
    nateglinide TEXT,
    chlorpropamide TEXT,
    glimepiride TEXT,
    acetohexamide TEXT,
    glipizide TEXT,
    glyburide TEXT,
    tolbutamide TEXT,
    pioglitazone TEXT,
    rosiglitazone TEXT,
    acarbose TEXT,
    miglitol TEXT,
    troglitazone TEXT,
    tolazamide TEXT,
    insulin TEXT,
    glyburide_metformin TEXT,
    glipizide_metformin TEXT,
    glimepiride_pioglitazone TEXT,
    metformin_rosiglitazone TEXT,
    metformin_pioglitazone TEXT,
    change TEXT,
    diabetesmed TEXT,
    admission_type_description TEXT,
    discharge_disposition_description TEXT,
    admission_source_description TEXT
);

-- =============================================================================
-- 2. LOAD THE TRAINING PARTITION INTO THE RAW TABLE
-- =============================================================================

-- Reset the validated development staging table before rebuilding the cohort.
--
-- This makes the loader rerunnable. Without this reset, rerunning the script
-- after a successful load would attempt to insert the same encounter_id values
-- again and the PRIMARY KEY constraint would correctly reject the duplicates.
--
-- The loader rebuilds only the development cohort (train + validation).
-- The held-out test partition is not loaded by this workflow.
TRUNCATE TABLE staging.development_encounters;

-- Reset the permissive raw landing table before loading the first partition.
-- This prevents records from a previous load from remaining in the landing area.
TRUNCATE TABLE staging.development_encounters_raw;


-- Import train.csv into the raw landing table.
--
-- \copy is a psql client command rather than standard SQL. The psql client
-- reads the local CSV file and sends the records to PostgreSQL.
--
-- The destination columns are listed explicitly so the source-to-database
-- mapping is visible and reproducible.
--
-- CSV HEADER tells PostgreSQL that the first row contains column names and
-- should not be imported as data.


-- Important:
--   \copy is a psql meta-command, so this command is intentionally kept on
--   one physical line. Breaking it across lines causes a psql parse error.
\copy staging.development_encounters_raw (encounter_id, patient_nbr, readmitted, readmitted_30d, race, gender, age, time_in_hospital, payer_code, medical_specialty, num_lab_procedures, num_procedures, num_medications, number_outpatient, number_emergency, number_inpatient, diag_1, diag_2, diag_3, number_diagnoses, max_glu_serum, a1cresult, metformin, repaglinide, nateglinide, chlorpropamide, glimepiride, acetohexamide, glipizide, glyburide, tolbutamide, pioglitazone, rosiglitazone, acarbose, miglitol, troglitazone, tolazamide, insulin, glyburide_metformin, glipizide_metformin, glimepiride_pioglitazone, metformin_rosiglitazone, metformin_pioglitazone, change, diabetesmed, admission_type_description, discharge_disposition_description, admission_source_description) FROM 'data/processed/train.csv' WITH (FORMAT csv, HEADER true)
-- QA_VALIDATE_RAW_DATA: TRAIN
SELECT pg_temp.validate_raw_data(71520, 'train');



-- =============================================================================
-- 3. VERIFY THE RAW TRAINING LOAD
-- =============================================================================

-- Confirm that the imported training partition matches the expected source
-- structure before any records are promoted into the validated staging table.
--
-- Expected results:
--   Total rows:               71,520
--   Unique encounter IDs:     71,520
--   Unique patients:          50,062
--   Duplicate encounter IDs:       0
--
-- Why this check matters:
--   COPY confirms how many rows PostgreSQL received, but it does not prove
--   that encounter identifiers are unique or that the loaded cohort matches
--   the expected training partition.

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT encounter_id) AS unique_encounters,
    COUNT(DISTINCT patient_nbr) AS unique_patients,
    COUNT(*) - COUNT(DISTINCT encounter_id) AS duplicate_encounter_ids
FROM staging.development_encounters_raw;

-- Verify that the binary 30-day readmission target remains consistent with
-- the original three-category readmission outcome.
--
-- Expected valid mappings:
--   readmitted = '<30'  -> readmitted_30d = 1
--   readmitted = '>30'  -> readmitted_30d = 0
--   readmitted = 'NO'   -> readmitted_30d = 0
--
-- Any additional combination would indicate a target-lineage problem that
-- should be investigated before records are promoted.

SELECT
    readmitted,
    readmitted_30d,
    COUNT(*) AS encounter_count
FROM staging.development_encounters_raw
GROUP BY
    readmitted,
    readmitted_30d
ORDER BY
    readmitted,
    readmitted_30d;

-- Verify that every raw TEXT field destined for a PostgreSQL numeric type
-- contains integer-compatible values before type conversion.
--
-- PostgreSQL regular-expression operator:
--   !~ means "does not match."
--
-- Regular expression:
--   ^[0-9]+$
--
-- Meaning:
--   ^       = start of the value
--   [0-9]   = any digit from 0 through 9
--   +       = one or more digits
--   $       = end of the value
--
-- Expected result:
--   Every "bad_*" count should equal 0.
--
-- Why this check matters:
--   The raw landing table stores these fields as TEXT. This audit verifies
--   that they can safely be converted to BIGINT, INTEGER, or SMALLINT when
--   records are promoted into the strongly typed staging table.

SELECT
    COUNT(*) FILTER (WHERE encounter_id !~ '^[0-9]+$') AS bad_encounter_id,
    COUNT(*) FILTER (WHERE patient_nbr !~ '^[0-9]+$') AS bad_patient_nbr,
    COUNT(*) FILTER (WHERE readmitted_30d !~ '^[0-9]+$') AS bad_readmitted_30d,
    COUNT(*) FILTER (WHERE time_in_hospital !~ '^[0-9]+$') AS bad_time_in_hospital,
    COUNT(*) FILTER (WHERE num_lab_procedures !~ '^[0-9]+$') AS bad_num_lab_procedures,
    COUNT(*) FILTER (WHERE num_procedures !~ '^[0-9]+$') AS bad_num_procedures,
    COUNT(*) FILTER (WHERE num_medications !~ '^[0-9]+$') AS bad_num_medications,
    COUNT(*) FILTER (WHERE number_outpatient !~ '^[0-9]+$') AS bad_number_outpatient,
    COUNT(*) FILTER (WHERE number_emergency !~ '^[0-9]+$') AS bad_number_emergency,
    COUNT(*) FILTER (WHERE number_inpatient !~ '^[0-9]+$') AS bad_number_inpatient,
    COUNT(*) FILTER (WHERE number_diagnoses !~ '^[0-9]+$') AS bad_number_diagnoses
FROM staging.development_encounters_raw;

-- Verify that the convertible numeric values also satisfy the semantic
-- constraints defined by staging.development_encounters.
--
-- This is different from the previous numeric-convertibility check:
--   Convertibility asks: "Can this TEXT value become a number?"
--   This check asks:     "Is that number allowed by our data contract?"
--
-- Expected result:
--   Every "bad_*" count should equal 0.
--
-- Note:
--   We enforce meaningful lower bounds and target-domain rules here.
--   Observed dataset maxima are not treated as universal constraints.

SELECT
    COUNT(*) FILTER (
        WHERE readmitted_30d::SMALLINT NOT IN (0, 1)
    ) AS bad_readmitted_30d,

    COUNT(*) FILTER (
        WHERE time_in_hospital::INTEGER < 1
    ) AS bad_time_in_hospital,

    COUNT(*) FILTER (
        WHERE num_lab_procedures::INTEGER < 0
    ) AS bad_num_lab_procedures,

    COUNT(*) FILTER (
        WHERE num_procedures::INTEGER < 0
    ) AS bad_num_procedures,

    COUNT(*) FILTER (
        WHERE num_medications::INTEGER < 0
    ) AS bad_num_medications,

    COUNT(*) FILTER (
        WHERE number_outpatient::INTEGER < 0
    ) AS bad_number_outpatient,

    COUNT(*) FILTER (
        WHERE number_emergency::INTEGER < 0
    ) AS bad_number_emergency,

    COUNT(*) FILTER (
        WHERE number_inpatient::INTEGER < 0
    ) AS bad_number_inpatient,

    COUNT(*) FILTER (
        WHERE number_diagnoses::INTEGER < 1
    ) AS bad_number_diagnoses
FROM staging.development_encounters_raw;


-- =============================================================================
-- 4. PROMOTE THE TRAINING PARTITION INTO THE VALIDATED STAGING TABLE
-- =============================================================================

-- Convert the permissive raw TEXT representation into the strongly typed
-- staging structure.
--
-- Numeric fields are explicitly cast to their destination PostgreSQL types.
-- Categorical fields remain TEXT and preserve source categories such as
-- "Unknown", "Not Available", "Not Mapped", "Not recorded", and "Missing".
--
-- The source_partition value does not exist in train.csv. It is added here
-- explicitly so every encounter retains its source-partition lineage.
--
-- Important:
--   discharge_disposition_description is retained for descriptive SQL and BI
--   analysis, but its presence here does not make it an approved ML predictor.
--
-- Expected result:
--   71,520 training encounters inserted.

INSERT INTO staging.development_encounters (
    encounter_id,
    patient_nbr,
    readmitted,
    readmitted_30d,
    race,
    gender,
    age,
    time_in_hospital,
    payer_code,
    medical_specialty,
    num_lab_procedures,
    num_procedures,
    num_medications,
    number_outpatient,
    number_emergency,
    number_inpatient,
    diag_1,
    diag_2,
    diag_3,
    number_diagnoses,
    max_glu_serum,
    a1cresult,
    metformin,
    repaglinide,
    nateglinide,
    chlorpropamide,
    glimepiride,
    acetohexamide,
    glipizide,
    glyburide,
    tolbutamide,
    pioglitazone,
    rosiglitazone,
    acarbose,
    miglitol,
    troglitazone,
    tolazamide,
    insulin,
    glyburide_metformin,
    glipizide_metformin,
    glimepiride_pioglitazone,
    metformin_rosiglitazone,
    metformin_pioglitazone,
    change,
    diabetesmed,
    admission_type_description,
    discharge_disposition_description,
    admission_source_description,
    source_partition
)
SELECT
    encounter_id::BIGINT,
    patient_nbr::BIGINT,
    readmitted,
    readmitted_30d::SMALLINT,
    race,
    gender,
    age,
    time_in_hospital::INTEGER,
    payer_code,
    medical_specialty,
    num_lab_procedures::INTEGER,
    num_procedures::INTEGER,
    num_medications::INTEGER,
    number_outpatient::INTEGER,
    number_emergency::INTEGER,
    number_inpatient::INTEGER,
    diag_1,
    diag_2,
    diag_3,
    number_diagnoses::INTEGER,
    max_glu_serum,
    a1cresult,
    metformin,
    repaglinide,
    nateglinide,
    chlorpropamide,
    glimepiride,
    acetohexamide,
    glipizide,
    glyburide,
    tolbutamide,
    pioglitazone,
    rosiglitazone,
    acarbose,
    miglitol,
    troglitazone,
    tolazamide,
    insulin,
    glyburide_metformin,
    glipizide_metformin,
    glimepiride_pioglitazone,
    metformin_rosiglitazone,
    metformin_pioglitazone,
    change,
    diabetesmed,
    admission_type_description,
    discharge_disposition_description,
    admission_source_description,

    -- Add explicit lineage because this batch came from train.csv.
    'train' AS source_partition

FROM staging.development_encounters_raw;


-- =============================================================================
-- 5. VERIFY THE PROMOTED TRAINING PARTITION
-- =============================================================================

-- Confirm that the validated staging table contains the expected training
-- cohort after promotion.
--
-- Expected result:
--   total_rows        = 71,520
--   unique_encounters = 71,520
--   unique_patients   = 50,062
--   training_rows     = 71,520
--   validation_rows   = 0
--
-- The partition counts verify that the lineage value added during promotion
-- was applied correctly to every training encounter.

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT encounter_id) AS unique_encounters,
    COUNT(DISTINCT patient_nbr) AS unique_patients,
    COUNT(*) FILTER (WHERE source_partition = 'train') AS training_rows,
    COUNT(*) FILTER (WHERE source_partition = 'validation') AS validation_rows
FROM staging.development_encounters;


-- Reconcile the raw training landing table against the validated table.
--
-- The LEFT JOIN starts with every raw encounter and looks for the same
-- encounter_id in the validated table.
--
-- Expected result:
--   raw_rows                        = 71,520
--   validated_rows                  = 71,520
--   raw_rows_missing_from_validated = 0
--
-- A missing count of 0 confirms that no raw training encounter disappeared
-- during the raw-to-validated promotion.

SELECT
    (SELECT COUNT(*)
     FROM staging.development_encounters_raw) AS raw_rows,

    (SELECT COUNT(*)
     FROM staging.development_encounters) AS validated_rows,

    (SELECT COUNT(*)
     FROM staging.development_encounters_raw AS raw
     LEFT JOIN staging.development_encounters AS validated
         ON raw.encounter_id::BIGINT = validated.encounter_id
     WHERE validated.encounter_id IS NULL) AS raw_rows_missing_from_validated;


-- =============================================================================
-- 6. LOAD THE VALIDATION PARTITION INTO THE RAW TABLE
-- =============================================================================

-- The training partition has already been promoted into
-- staging.development_encounters, so do NOT truncate the validated table here.
--
-- Only reset the reusable raw landing table before loading validation.csv.
TRUNCATE TABLE staging.development_encounters_raw;


-- Import validation.csv into the raw landing table.
--
-- The destination columns are listed explicitly so the CSV-to-PostgreSQL
-- mapping remains visible and reproducible.
--
-- Important:
--   \copy is a psql meta-command, so this command is intentionally kept on
--   one physical line. Breaking it across lines causes a psql parse error.
--
-- Expected result:
--   COPY 15027

\copy staging.development_encounters_raw (encounter_id, patient_nbr, readmitted, readmitted_30d, race, gender, age, time_in_hospital, payer_code, medical_specialty, num_lab_procedures, num_procedures, num_medications, number_outpatient, number_emergency, number_inpatient, diag_1, diag_2, diag_3, number_diagnoses, max_glu_serum, a1cresult, metformin, repaglinide, nateglinide, chlorpropamide, glimepiride, acetohexamide, glipizide, glyburide, tolbutamide, pioglitazone, rosiglitazone, acarbose, miglitol, troglitazone, tolazamide, insulin, glyburide_metformin, glipizide_metformin, glimepiride_pioglitazone, metformin_rosiglitazone, metformin_pioglitazone, change, diabetesmed, admission_type_description, discharge_disposition_description, admission_source_description) FROM 'data/processed/validation.csv' WITH (FORMAT csv, HEADER true)
-- QA_VALIDATE_RAW_DATA: VALIDATION
SELECT pg_temp.validate_raw_data(15027, 'validation');



-- Verify the validation CSV landed with the expected encounter and patient
-- counts before any rows are promoted into the validated staging table.
--
-- Expected result:
--   total_rows              = 15,027
--   unique_encounters       = 15,027
--   unique_patients         = 10,728
--   duplicate_encounter_ids = 0

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT encounter_id) AS unique_encounters,
    COUNT(DISTINCT patient_nbr) AS unique_patients,
    COUNT(*) - COUNT(DISTINCT encounter_id) AS duplicate_encounter_ids
FROM staging.development_encounters_raw;

-- Verify that the binary early-readmission target remains consistent with
-- the original multiclass readmission outcome.
--
-- Expected valid mappings:
--   <30 -> 1
--   >30 -> 0
--   NO  -> 0
--
-- Expected validation counts:
--   <30 -> 1 = 1,656
--   >30 -> 0 = 5,159
--   NO  -> 0 = 8,212
--
-- Any additional combination should be investigated before promotion.

SELECT
    readmitted,
    readmitted_30d,
    COUNT(*) AS encounter_count
FROM staging.development_encounters_raw
GROUP BY
    readmitted,
    readmitted_30d
ORDER BY
    readmitted,
    readmitted_30d;


-- Verify that every raw TEXT field that will be converted to a PostgreSQL
-- numeric type contains a valid non-negative integer representation.
--
-- The !~ operator means "does not match this regular expression."
-- ^[0-9]+$ means the entire value must contain one or more digits.
--
-- Expected result:
--   Every "bad_*" count should equal 0.
--
-- This test verifies conversion safety. Semantic rules such as
-- time_in_hospital >= 1 are checked separately below.

SELECT
    COUNT(*) FILTER (WHERE encounter_id !~ '^[0-9]+$') AS bad_encounter_id,
    COUNT(*) FILTER (WHERE patient_nbr !~ '^[0-9]+$') AS bad_patient_nbr,
    COUNT(*) FILTER (WHERE readmitted_30d !~ '^[0-9]+$') AS bad_readmitted_30d,
    COUNT(*) FILTER (WHERE time_in_hospital !~ '^[0-9]+$') AS bad_time_in_hospital,
    COUNT(*) FILTER (WHERE num_lab_procedures !~ '^[0-9]+$') AS bad_num_lab_procedures,
    COUNT(*) FILTER (WHERE num_procedures !~ '^[0-9]+$') AS bad_num_procedures,
    COUNT(*) FILTER (WHERE num_medications !~ '^[0-9]+$') AS bad_num_medications,
    COUNT(*) FILTER (WHERE number_outpatient !~ '^[0-9]+$') AS bad_number_outpatient,
    COUNT(*) FILTER (WHERE number_emergency !~ '^[0-9]+$') AS bad_number_emergency,
    COUNT(*) FILTER (WHERE number_inpatient !~ '^[0-9]+$') AS bad_number_inpatient,
    COUNT(*) FILTER (WHERE number_diagnoses !~ '^[0-9]+$') AS bad_number_diagnoses
FROM staging.development_encounters_raw;


-- Verify that the convertible numeric values also satisfy the semantic
-- constraints defined by staging.development_encounters.
--
-- Expected result:
--   Every "bad_*" count should equal 0.
--
-- PostgreSQL's :: syntax performs an explicit type cast. For example,
-- time_in_hospital::INTEGER converts the raw TEXT value to INTEGER before
-- evaluating the semantic rule.

SELECT
    COUNT(*) FILTER (
        WHERE readmitted_30d::SMALLINT NOT IN (0, 1)
    ) AS bad_readmitted_30d,

    COUNT(*) FILTER (
        WHERE time_in_hospital::INTEGER < 1
    ) AS bad_time_in_hospital,

    COUNT(*) FILTER (
        WHERE num_lab_procedures::INTEGER < 0
    ) AS bad_num_lab_procedures,

    COUNT(*) FILTER (
        WHERE num_procedures::INTEGER < 0
    ) AS bad_num_procedures,

    COUNT(*) FILTER (
        WHERE num_medications::INTEGER < 0
    ) AS bad_num_medications,

    COUNT(*) FILTER (
        WHERE number_outpatient::INTEGER < 0
    ) AS bad_number_outpatient,

    COUNT(*) FILTER (
        WHERE number_emergency::INTEGER < 0
    ) AS bad_number_emergency,

    COUNT(*) FILTER (
        WHERE number_inpatient::INTEGER < 0
    ) AS bad_number_inpatient,

    COUNT(*) FILTER (
        WHERE number_diagnoses::INTEGER < 1
    ) AS bad_number_diagnoses
FROM staging.development_encounters_raw;


-- =============================================================================
-- 7. PROMOTE THE VALIDATION PARTITION INTO THE VALIDATED STAGING TABLE
-- =============================================================================

-- Convert the validated raw TEXT representation into the strongly typed
-- staging structure.
--
-- The transformation is intentionally the same as the training promotion.
-- The key lineage difference is source_partition = 'validation'.
--
-- Expected result:
--   15,027 validation encounters inserted.
--
-- After this promotion, staging.development_encounters should contain:
--   train      = 71,520
--   validation = 15,027
--   total      = 86,547

INSERT INTO staging.development_encounters (
    encounter_id,
    patient_nbr,
    readmitted,
    readmitted_30d,
    race,
    gender,
    age,
    time_in_hospital,
    payer_code,
    medical_specialty,
    num_lab_procedures,
    num_procedures,
    num_medications,
    number_outpatient,
    number_emergency,
    number_inpatient,
    diag_1,
    diag_2,
    diag_3,
    number_diagnoses,
    max_glu_serum,
    a1cresult,
    metformin,
    repaglinide,
    nateglinide,
    chlorpropamide,
    glimepiride,
    acetohexamide,
    glipizide,
    glyburide,
    tolbutamide,
    pioglitazone,
    rosiglitazone,
    acarbose,
    miglitol,
    troglitazone,
    tolazamide,
    insulin,
    glyburide_metformin,
    glipizide_metformin,
    glimepiride_pioglitazone,
    metformin_rosiglitazone,
    metformin_pioglitazone,
    change,
    diabetesmed,
    admission_type_description,
    discharge_disposition_description,
    admission_source_description,
    source_partition
)
SELECT
    encounter_id::BIGINT,
    patient_nbr::BIGINT,
    readmitted,
    readmitted_30d::SMALLINT,
    race,
    gender,
    age,
    time_in_hospital::INTEGER,
    payer_code,
    medical_specialty,
    num_lab_procedures::INTEGER,
    num_procedures::INTEGER,
    num_medications::INTEGER,
    number_outpatient::INTEGER,
    number_emergency::INTEGER,
    number_inpatient::INTEGER,
    diag_1,
    diag_2,
    diag_3,
    number_diagnoses::INTEGER,
    max_glu_serum,
    a1cresult,
    metformin,
    repaglinide,
    nateglinide,
    chlorpropamide,
    glimepiride,
    acetohexamide,
    glipizide,
    glyburide,
    tolbutamide,
    pioglitazone,
    rosiglitazone,
    acarbose,
    miglitol,
    troglitazone,
    tolazamide,
    insulin,
    glyburide_metformin,
    glipizide_metformin,
    glimepiride_pioglitazone,
    metformin_rosiglitazone,
    metformin_pioglitazone,
    change,
    diabetesmed,
    admission_type_description,
    discharge_disposition_description,
    admission_source_description,

    -- Add explicit lineage because this batch came from validation.csv.
    'validation' AS source_partition

FROM staging.development_encounters_raw;


-- =============================================================================
-- 8. FINAL DEVELOPMENT-COHORT RECONCILIATION
-- =============================================================================

-- Verify the complete development cohort after both source partitions have
-- been promoted into the validated staging table.
--
-- Expected result:
--   total_rows          = 86,547
--   unique_encounters   = 86,547
--   unique_patients     = 60,790
--   training_rows       = 71,520
--   validation_rows     = 15,027
--
-- The held-out test partition is intentionally excluded from these counts.

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT encounter_id) AS unique_encounters,
    COUNT(DISTINCT patient_nbr) AS unique_patients,
    COUNT(*) FILTER (
        WHERE source_partition = 'train'
    ) AS training_rows,
    COUNT(*) FILTER (
        WHERE source_partition = 'validation'
    ) AS validation_rows
FROM staging.development_encounters;


-- Verify that the patient-level train/validation split remains isolated.
--
-- The machine-learning workflow used patient-aware partitioning, so a patient
-- must not appear in both the training and validation partitions.
--
-- Expected result:
--   overlapping_patients = 0
--
-- A nonzero result would indicate patient leakage across development
-- partitions and should stop downstream analytical/model-linked work.

SELECT
    COUNT(*) AS overlapping_patients
FROM (
    SELECT patient_nbr
    FROM staging.development_encounters
    GROUP BY patient_nbr
    HAVING COUNT(DISTINCT source_partition) > 1
) AS patient_partition_overlap;


-- Verify the encounter-level partition boundary explicitly.
--
-- encounter_id is already protected by the PRIMARY KEY constraint, so the
-- database cannot store the same encounter twice. This query documents that
-- integrity condition as part of the reproducible loading audit.
--
-- Expected result:
--   duplicate_encounter_ids = 0

SELECT
    COUNT(*) - COUNT(DISTINCT encounter_id) AS duplicate_encounter_ids
FROM staging.development_encounters;


-- Reconcile the binary target across the complete development cohort.
--
-- Expected result:
--   readmitted_30d = 0 -> 76,870 encounters
--   readmitted_30d = 1 ->  9,677 encounters
--   total               -> 86,547 encounters

SELECT
    readmitted_30d,
    COUNT(*) AS encounter_count
FROM staging.development_encounters
GROUP BY readmitted_30d
ORDER BY readmitted_30d;




-- QA_FINAL_RECONCILIATION
-- All assertions must pass before the transaction can commit.

DO $$
DECLARE
    train_rows BIGINT;
    validation_rows BIGINT;
    total_rows BIGINT;
    unique_patients BIGINT;
    train_positive BIGINT;
    validation_positive BIGINT;
    duplicate_encounters BIGINT;
    overlapping_patients BIGINT;
    invalid_mappings BIGINT;
BEGIN
    SELECT
        COUNT(*) FILTER (WHERE source_partition = 'train'),
        COUNT(*) FILTER (WHERE source_partition = 'validation'),
        COUNT(*),
        COUNT(DISTINCT patient_nbr),
        COUNT(*) FILTER (
            WHERE source_partition = 'train' AND readmitted_30d = 1
        ),
        COUNT(*) FILTER (
            WHERE source_partition = 'validation' AND readmitted_30d = 1
        ),
        COUNT(*) - COUNT(DISTINCT encounter_id),
        COUNT(*) FILTER (
            WHERE readmitted NOT IN ('<30', '>30', 'NO')
               OR readmitted_30d <>
                  CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END
        )
    INTO
        train_rows,
        validation_rows,
        total_rows,
        unique_patients,
        train_positive,
        validation_positive,
        duplicate_encounters,
        invalid_mappings
    FROM staging.development_encounters;

    SELECT COUNT(*)
    INTO overlapping_patients
    FROM (
        SELECT patient_nbr
        FROM staging.development_encounters
        GROUP BY patient_nbr
        HAVING COUNT(DISTINCT source_partition) > 1
    ) overlap_check;

    IF train_rows <> 71520
       OR validation_rows <> 15027
       OR total_rows <> 86547
       OR unique_patients <> 60790
       OR train_positive <> 8021
       OR validation_positive <> 1656
       OR duplicate_encounters <> 0
       OR overlapping_patients <> 0
       OR invalid_mappings <> 0
    THEN
        RAISE EXCEPTION
            'FINAL DATA RECONCILIATION FAILED:
             train=%, validation=%, total=%,
             patients=%, train_positive=%,
             validation_positive=%, duplicates=%,
             patient_overlap=%, target_errors=%',
            train_rows,
            validation_rows,
            total_rows,
            unique_patients,
            train_positive,
            validation_positive,
            duplicate_encounters,
            overlapping_patients,
            invalid_mappings;
    END IF;

    RAISE NOTICE
        'FINAL DATA RECONCILIATION PASSED: % encounters, % patients, % readmissions',
        total_rows,
        unique_patients,
        train_positive + validation_positive;
END
$$;

-- QA TRANSACTION BOUNDARY
COMMIT;
