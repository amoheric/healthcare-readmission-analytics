-- =============================================================================
-- Healthcare Readmission Analytics
-- File: 01_schema.sql
--
-- Purpose:
--   Create the PostgreSQL schemas and the initial staging table used by the
--   SQL and BI portion of the healthcare readmission portfolio project.
--
-- Development-data boundary:
--   This database layer initially uses only the training and validation
--   partitions (86,547 encounters).
--
--   The held-out HGB test partition is deliberately excluded from this
--   development SQL/BI workflow.
--
-- Grain:
--   One row in staging.development_encounters represents one hospital
--   encounter.
--
-- Important:
--   "Unknown", "Not Available", "Not Mapped", "Not recorded", "Missing",
--   and similar source categories are preserved as categorical values.
--   They are not automatically converted to SQL NULL.
-- =============================================================================


-- =============================================================================
-- 1. CREATE LOGICAL DATABASE SCHEMAS
-- =============================================================================

-- Create a schema for data loaded from development source files.
-- Think of "staging" as the controlled landing area for imported data.
CREATE SCHEMA IF NOT EXISTS staging;


-- Create a schema for validated tables used in analytical SQL.
-- We will populate this layer only after the staging data passes quality checks.
CREATE SCHEMA IF NOT EXISTS analytics;


-- Create a schema for stable views that will later feed Power BI.
CREATE SCHEMA IF NOT EXISTS reporting;


-- =============================================================================
-- 2. CREATE THE DEVELOPMENT ENCOUNTER STAGING TABLE
-- =============================================================================

-- Create the main staging table.
--
-- Each row represents one hospital encounter from either the existing
-- training partition or validation partition.
CREATE TABLE IF NOT EXISTS staging.development_encounters (

    -- -------------------------------------------------------------------------
    -- IDENTIFIERS
    -- -------------------------------------------------------------------------

    -- Unique identifier for an individual hospital encounter.
    --
    -- BIGINT is used because encounter identifiers are identifiers rather than
    -- measurements and may require more range than a standard INTEGER.
    --
    -- PRIMARY KEY tells PostgreSQL that:
    --   1. encounter_id must be unique; and
    --   2. encounter_id cannot be NULL.
    encounter_id BIGINT PRIMARY KEY,

    -- Identifier used to connect multiple encounters belonging to the same
    -- patient.
    --
    -- patient_nbr is NOT a primary key because one patient may have multiple
    -- hospital encounters.
    patient_nbr BIGINT NOT NULL,


    -- -------------------------------------------------------------------------
    -- OUTCOMES
    -- -------------------------------------------------------------------------

    -- Original three-level outcome from the processed source data:
    --   '<30' = readmitted within 30 days
    --   '>30' = readmitted after 30 days
    --   'NO'  = no recorded readmission
    readmitted TEXT NOT NULL,

    -- Binary target used by the machine-learning workflow:
    --   1 = readmitted within 30 days
    --   0 = not readmitted within 30 days
    --
    -- SMALLINT is sufficient for the values 0 and 1.
    -- The CHECK constraint prevents any other value from being stored.
    readmitted_30d SMALLINT NOT NULL
        CHECK (readmitted_30d IN (0, 1)),


    -- -------------------------------------------------------------------------
    -- DEMOGRAPHICS
    -- -------------------------------------------------------------------------

    -- Race category from the processed source data.
    -- "Unknown" remains an explicit category rather than SQL NULL.
    race TEXT NOT NULL,

    -- Recorded gender category.
    -- The source includes one "Unknown/Invalid" development-cohort record,
    -- which is deliberately preserved rather than silently recoded.
    gender TEXT NOT NULL,

    -- Age is stored as an interval category such as '[60-70)' rather than
    -- as an exact numeric age, so TEXT is the appropriate SQL type.
    age TEXT NOT NULL,


    -- -------------------------------------------------------------------------
    -- ENCOUNTER CHARACTERISTICS
    -- -------------------------------------------------------------------------

    -- Number of days spent in the hospital during the encounter.
    --
    -- The development data currently ranges from 1 to 14 days.
    -- We enforce only the meaningful lower bound rather than treating the
    -- observed maximum of 14 as a universal business rule.
    time_in_hospital INTEGER NOT NULL
        CHECK (time_in_hospital >= 1),

    -- Payer category/code.
    -- "Unknown" is retained as an explicit source category.
    payer_code TEXT NOT NULL,

    -- Medical specialty associated with the encounter.
    medical_specialty TEXT NOT NULL,


    -- -------------------------------------------------------------------------
    -- PROCEDURES, MEDICATIONS, AND PRIOR UTILIZATION COUNTS
    -- -------------------------------------------------------------------------

    -- Number of laboratory procedures recorded during the encounter.
    num_lab_procedures INTEGER NOT NULL
        CHECK (num_lab_procedures >= 0),

    -- Number of non-laboratory procedures recorded during the encounter.
    num_procedures INTEGER NOT NULL
        CHECK (num_procedures >= 0),

    -- Number of medications recorded during the encounter.
    num_medications INTEGER NOT NULL
        CHECK (num_medications >= 0),

    -- Number of outpatient visits recorded before the current encounter.
    number_outpatient INTEGER NOT NULL
        CHECK (number_outpatient >= 0),

    -- Number of emergency visits recorded before the current encounter.
    number_emergency INTEGER NOT NULL
        CHECK (number_emergency >= 0),

    -- Number of inpatient visits recorded before the current encounter.
    number_inpatient INTEGER NOT NULL
        CHECK (number_inpatient >= 0),


    -- -------------------------------------------------------------------------
    -- DIAGNOSES
    -- -------------------------------------------------------------------------

    -- Primary diagnosis code.
    --
    -- Diagnosis codes are intentionally stored as TEXT because the source
    -- contains values such as '250.8' and 'V57'. Treating these as numeric
    -- measurements would corrupt their meaning.
    diag_1 TEXT NOT NULL,

    -- Secondary diagnosis code.
    diag_2 TEXT NOT NULL,

    -- Additional diagnosis code.
    --
    -- The processed source may contain the explicit category "Missing".
    diag_3 TEXT NOT NULL,

    -- Number of diagnoses associated with the encounter.
    number_diagnoses INTEGER NOT NULL
        CHECK (number_diagnoses >= 1),


    -- -------------------------------------------------------------------------
    -- LABORATORY / GLYCEMIC RESULTS
    -- -------------------------------------------------------------------------

    -- Maximum serum glucose result category.
    -- "Not recorded" is preserved as an explicit category.
    max_glu_serum TEXT NOT NULL,

    -- HbA1c result category.
    -- "Not recorded" is preserved as an explicit category.
    a1cresult TEXT NOT NULL,


    -- -------------------------------------------------------------------------
    -- DIABETES MEDICATION VARIABLES
    -- -------------------------------------------------------------------------

    -- Medication status variables are categorical rather than numeric doses.
    metformin TEXT NOT NULL,
    repaglinide TEXT NOT NULL,
    nateglinide TEXT NOT NULL,
    chlorpropamide TEXT NOT NULL,
    glimepiride TEXT NOT NULL,
    acetohexamide TEXT NOT NULL,
    glipizide TEXT NOT NULL,
    glyburide TEXT NOT NULL,
    tolbutamide TEXT NOT NULL,
    pioglitazone TEXT NOT NULL,
    rosiglitazone TEXT NOT NULL,
    acarbose TEXT NOT NULL,
    miglitol TEXT NOT NULL,
    troglitazone TEXT NOT NULL,
    tolazamide TEXT NOT NULL,
    insulin TEXT NOT NULL,

    -- Combination medication variables.
    glyburide_metformin TEXT NOT NULL,
    glipizide_metformin TEXT NOT NULL,
    glimepiride_pioglitazone TEXT NOT NULL,
    metformin_rosiglitazone TEXT NOT NULL,
    metformin_pioglitazone TEXT NOT NULL,

    -- Indicates whether diabetes medication was changed during the encounter.
    change TEXT NOT NULL,

    -- Indicates whether a diabetes medication was prescribed.
    diabetesmed TEXT NOT NULL,


    -- -------------------------------------------------------------------------
    -- HUMAN-READABLE ENCOUNTER DESCRIPTIONS
    -- -------------------------------------------------------------------------

    -- Human-readable admission type.
    admission_type_description TEXT NOT NULL,

    -- Human-readable discharge disposition.
    --
    -- This field remains available for descriptive SQL and lineage.
    -- Its presence here does NOT make it an approved ML predictor.
    discharge_disposition_description TEXT NOT NULL,

    -- Human-readable source of admission.
    admission_source_description TEXT NOT NULL,


    -- -------------------------------------------------------------------------
    -- DATA LINEAGE
    -- -------------------------------------------------------------------------

    -- Records whether the encounter came from the existing training or
    -- validation partition.
    --
    -- This column is created specifically for the SQL/BI layer and was not
    -- one of the original 48 columns in either processed CSV.
    source_partition TEXT NOT NULL
        CHECK (source_partition IN ('train', 'validation'))
);