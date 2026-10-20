-- =============================================================================
-- 1. TOTAL DEVELOPMENT ENCOUNTERS
-- =============================================================================

-- Count every encounter currently included in the development cohort.
--
-- The development cohort contains the training and validation partitions.
-- The held-out test partition is intentionally excluded.
--
-- Expected result:
--   86,547 encounters

SELECT
    -- COUNT(*) counts every row returned by the query.
    COUNT(*) AS total_encounters

-- Read the encounter records from the validated PostgreSQL staging table.
FROM staging.development_encounters;


-- =============================================================================
-- 2. OVERALL 30-DAY READMISSION KPI
-- =============================================================================

-- Count the encounters where the patient was readmitted within 30 days.
--
-- The readmitted_30d column is a binary target:
--   1 = readmitted within 30 days
--   0 = not readmitted within 30 days
--
-- We also calculate the percentage of development encounters that resulted
-- in a 30-day readmission.
--
-- Expected result:
--   total_encounters        = 86,547
--   readmitted_30d_encounters = 9,677
--   readmission_rate_pct    ≈ 11.18%

SELECT
    -- Count every encounter in the development cohort.
    COUNT(*) AS total_encounters,

    -- Add the binary target values.
    -- Because the target contains only 0 and 1, SUM() gives us the
    -- number of encounters where readmitted_30d = 1.
    SUM(readmitted_30d) AS readmitted_30d_encounters,

    -- Convert the readmission count into a percentage of all encounters.
    --
    -- Multiplying by 100 converts the proportion into a percentage.
    -- NULLIF(total_count, 0) protects against division by zero.
    ROUND(
        100.0 * SUM(readmitted_30d)
        / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate_pct

-- Use the validated development cohort as the analytical source.
FROM staging.development_encounters;


-- =============================================================================
-- 3. 30-DAY READMISSION RATE BY DATA PARTITION
-- =============================================================================

-- Compare the 30-day readmission rate between the training and validation
-- partitions.
--
-- This is useful as a data-quality and modeling-readiness check. The two
-- partitions should have reasonably similar target distributions because
-- they represent the same underlying development population.
--
-- Expected approximate results:
--   train      -> 11.22%
--   validation -> 11.02%

SELECT
    -- Identify which development partition the encounters came from.
    source_partition,

    -- Count all encounters within each partition.
    COUNT(*) AS total_encounters,

    -- Sum the binary target to count 30-day readmissions.
    SUM(readmitted_30d) AS readmitted_30d_encounters,

    -- Calculate the 30-day readmission percentage within each partition.
    ROUND(
        100.0 * SUM(readmitted_30d)
        / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate_pct

-- Read from the validated development cohort.
FROM staging.development_encounters

-- Create one result row for each source partition.
GROUP BY source_partition

-- Display the partitions in a predictable order.
ORDER BY source_partition;


-- =============================================================================
-- 4. ORIGINAL READMISSION OUTCOME DISTRIBUTION
-- =============================================================================

-- Show how encounters are distributed across the original three-category
-- readmission outcome.
--
-- The source dataset contains three categories:
--   NO  = the patient was not readmitted during the measured period
--   >30 = the patient was readmitted, but more than 30 days later
--   <30 = the patient was readmitted within 30 days
--
-- Our binary modeling target, readmitted_30d, was derived from this field:
--   <30 -> 1
--   >30 -> 0
--   NO  -> 0
--
-- This query lets us see the original outcome distribution directly.

SELECT
    -- Display the original categorical readmission outcome.
    readmitted,

    -- Count encounters belonging to each outcome category.
    COUNT(*) AS encounter_count,

    -- Calculate each category's percentage of the development cohort.
    ROUND(
        100.0 * COUNT(*)
        / NULLIF(
            (SELECT COUNT(*)
             FROM staging.development_encounters),
            0
        ),
        2
    ) AS percentage_of_encounters

-- Read from the validated development cohort.
FROM staging.development_encounters

-- Create one result row for each original readmission category.
GROUP BY readmitted

-- Sort alphabetically by the original outcome label.
ORDER BY readmitted;


-- =============================================================================
-- 5. ENCOUNTER UTILIZATION SUMMARY
-- =============================================================================

-- Summarize several utilization-related measures across the development
-- cohort.
--
-- These metrics help describe the typical encounter and provide operational
-- context for later readmission analysis.
--
-- The measures below are encounter-level variables from the source dataset:
--   time_in_hospital   = length of the hospital stay
--   num_lab_procedures = number of laboratory procedures
--   num_procedures     = number of procedures performed
--   num_medications    = number of medications administered
--   number_diagnoses   = number of diagnoses recorded
--
-- We calculate minimum, maximum, and average values where appropriate.

SELECT
    -- Shortest recorded hospital stay.
    MIN(time_in_hospital) AS min_length_of_stay,

    -- Longest recorded hospital stay.
    MAX(time_in_hospital) AS max_length_of_stay,

    -- Average hospital stay across all encounters.
    ROUND(
        AVG(time_in_hospital),
        2
    ) AS avg_length_of_stay,

    -- Average number of laboratory procedures per encounter.
    ROUND(
        AVG(num_lab_procedures),
        2
    ) AS avg_lab_procedures,

    -- Average number of procedures per encounter.
    ROUND(
        AVG(num_procedures),
        2
    ) AS avg_procedures,

    -- Average number of medications per encounter.
    ROUND(
        AVG(num_medications),
        2
    ) AS avg_medications,

    -- Average number of diagnoses recorded per encounter.
    ROUND(
        AVG(number_diagnoses),
        2
    ) AS avg_diagnoses

-- Use the validated development cohort as the analytical source.
FROM staging.development_encounters;


-- =============================================================================
-- 6. 30-DAY READMISSION RATE BY LENGTH OF STAY
-- =============================================================================

-- Compare 30-day readmission outcomes across hospital-stay durations.
--
-- This helps us determine whether encounters with different lengths of stay
-- show different observed readmission rates.
--
-- Important:
--   This is descriptive analysis only.
--   A difference in readmission rates does NOT by itself prove that length
--   of stay causes readmission.
--
-- Each row in the result represents one hospital-stay duration.

SELECT
    -- Number of days the patient remained in the hospital.
    time_in_hospital AS length_of_stay_days,

    -- Count all encounters with this length of stay.
    COUNT(*) AS total_encounters,

    -- Count encounters that resulted in a 30-day readmission.
    SUM(readmitted_30d) AS readmitted_30d_encounters,

    -- Calculate the observed 30-day readmission rate for this stay length.
    ROUND(
        100.0 * SUM(readmitted_30d)
        / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate_pct

-- Use the validated development cohort.
FROM staging.development_encounters

-- Create one result row for each length-of-stay value.
GROUP BY time_in_hospital

-- Display hospital stays from shortest to longest.
ORDER BY time_in_hospital;


-- =============================================================================
-- 7. 30-DAY READMISSION RATE BY ADMISSION TYPE
-- =============================================================================

-- Compare 30-day readmission rates across different admission types.
--
-- Admission type describes how the hospital encounter was classified when
-- the patient was admitted.
--
-- This analysis can help identify whether observed readmission rates differ
-- across emergency, elective, urgent, and other admission categories.
--
-- Important:
--   This is descriptive analysis. A difference between admission types does
--   not establish that admission type itself causes readmission.
--
-- Small categories should be interpreted cautiously because a percentage
-- based on a very small number of encounters can be unstable.

SELECT
    -- Display the descriptive admission-type category.
    admission_type_description,

    -- Count all encounters within each admission category.
    COUNT(*) AS total_encounters,

    -- Count encounters that resulted in 30-day readmission.
    SUM(readmitted_30d) AS readmitted_30d_encounters,

    -- Calculate the observed 30-day readmission rate.
    ROUND(
        100.0 * SUM(readmitted_30d)
        / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate_pct,

    -- Flag categories with fewer than 100 encounters so small groups
    -- can be identified before interpreting their percentages.
    CASE
        WHEN COUNT(*) < 100 THEN 'Small sample'
        ELSE 'Sufficient volume'
    END AS volume_flag

-- Use the validated development cohort.
FROM staging.development_encounters

-- Create one result row for each admission type.
GROUP BY admission_type_description

-- Show the largest admission categories first.
ORDER BY total_encounters DESC;


-- =============================================================================
-- 8. 30-DAY READMISSION RATE BY GENDER
-- =============================================================================

-- Compare observed 30-day readmission rates across the gender categories
-- represented in the development cohort.
--
-- This is descriptive analysis. A difference between groups does not by
-- itself establish that gender causes a difference in readmission risk.
--
-- The source data contains:
--   Female
--   Male
--   Unknown/Invalid
--
-- The Unknown/Invalid category should be interpreted cautiously because
-- it contains very few observations.

SELECT
    -- Display the gender category represented in the source data.
    gender,

    -- Count all encounters belonging to each gender category.
    COUNT(*) AS total_encounters,

    -- Count encounters that resulted in a 30-day readmission.
    SUM(readmitted_30d) AS readmitted_30d_encounters,

    -- Calculate the observed 30-day readmission rate for each category.
    ROUND(
        100.0 * SUM(readmitted_30d)
        / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate_pct,

    -- Identify categories with fewer than 100 encounters.
    --
    -- Small groups can produce unstable percentages, so this flag prevents
    -- us from overinterpreting a rate based on very few observations.
    CASE
        WHEN COUNT(*) < 100 THEN 'Small sample'
        ELSE 'Sufficient volume'
    END AS volume_flag

-- Use the validated development cohort.
FROM staging.development_encounters

-- Create one result row for each gender category.
GROUP BY gender

-- Display the largest categories first.
ORDER BY total_encounters DESC;


-- =============================================================================
-- 9. 30-DAY READMISSION RATE BY AGE GROUP
-- =============================================================================

-- Compare observed 30-day readmission rates across the age groups provided
-- by the source dataset.
--
-- The age field is already represented as categorical ranges such as
-- [50-60) and [70-80). We preserve those source categories rather than
-- attempting to create an artificial exact age.
--
-- This analysis is descriptive. Differences between age groups do not by
-- themselves establish that age causes differences in readmission risk.
--
-- Small age groups should be interpreted cautiously because their rates may
-- be based on relatively few encounters.

SELECT
    -- Display the age-group category supplied by the source dataset.
    age AS age_group,

    -- Count all encounters within each age group.
    COUNT(*) AS total_encounters,

    -- Count encounters that resulted in a 30-day readmission.
    SUM(readmitted_30d) AS readmitted_30d_encounters,

    -- Calculate the observed 30-day readmission rate for each age group.
    ROUND(
        100.0 * SUM(readmitted_30d)
        / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate_pct,

    -- Flag very small groups before interpreting their percentages.
    CASE
        WHEN COUNT(*) < 100 THEN 'Small sample'
        ELSE 'Sufficient volume'
    END AS volume_flag

-- Use the validated development cohort.
FROM staging.development_encounters

-- Create one result row for each age group.
GROUP BY age

-- Order the source age bands alphabetically.
--
-- Because the source categories use a consistent "[lower-upper)" format,
-- alphabetical ordering also follows the numerical age-band sequence.
ORDER BY age;


-- =============================================================================
-- 10. 30-DAY READMISSION RATE BY RACE
-- =============================================================================

-- Compare observed 30-day readmission rates across the race categories
-- represented in the source dataset.
--
-- The source dataset contains categories such as:
--   Caucasian
--   AfricanAmerican
--   Hispanic
--   Asian
--   Other
--   Unknown
--
-- These labels are preserved as supplied by the source data.
--
-- This is descriptive analysis only. Differences between groups do not by
-- themselves establish that race causes differences in readmission risk.
--
-- Small groups should be interpreted cautiously.

SELECT
    -- Display the race category supplied by the source dataset.
    race,

    -- Count all encounters within each race category.
    COUNT(*) AS total_encounters,

    -- Count encounters that resulted in a 30-day readmission.
    SUM(readmitted_30d) AS readmitted_30d_encounters,

    -- Calculate the observed 30-day readmission rate.
    ROUND(
        100.0 * SUM(readmitted_30d)
        / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate_pct,

    -- Flag categories with fewer than 100 encounters.
    CASE
        WHEN COUNT(*) < 100 THEN 'Low volume'
        ELSE 'Higher volume'
    END AS volume_flag

-- Use the validated development cohort.
FROM staging.development_encounters

-- Create one result row for each race category.
GROUP BY race

-- Display the largest race categories first.
ORDER BY total_encounters DESC;


-- =============================================================================
-- 11. 30-DAY READMISSION RATE BY DIABETES MEDICATION STATUS
-- =============================================================================

-- Compare observed 30-day readmission rates between encounters where
-- diabetes medication was recorded as active and encounters where it was not.
--
-- This variable describes medication status in the source encounter data.
-- It should not be interpreted as proof that medication use causes or prevents
-- readmission.
--
-- The analysis is descriptive and is intended to identify differences that
-- may warrant deeper investigation.

SELECT
    -- Display the diabetes medication status.
    diabetesmed AS diabetes_medication_status,

    -- Count all encounters within each medication-status category.
    COUNT(*) AS total_encounters,

    -- Count encounters that resulted in a 30-day readmission.
    SUM(readmitted_30d) AS readmitted_30d_encounters,

    -- Calculate the observed 30-day readmission rate.
    ROUND(
        100.0 * SUM(readmitted_30d)
        / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate_pct,

    -- Flag categories with fewer than 100 encounters.
    CASE
        WHEN COUNT(*) < 100 THEN 'Low volume'
        ELSE 'Higher volume'
    END AS volume_flag

-- Use the validated development cohort.
FROM staging.development_encounters

-- Create one result row for each medication-status category.
GROUP BY diabetesmed

-- Display the largest category first.
ORDER BY total_encounters DESC;


-- =============================================================================
-- 12. 30-DAY READMISSION RATE BY A1C RESULT
-- =============================================================================

-- Compare observed 30-day readmission rates across the A1C result categories
-- recorded in the source dataset.
--
-- The source categories are preserved exactly:
--   Not recorded
--   >8
--   Norm
--   >7
--
-- This analysis is descriptive. Differences in readmission rates do not by
-- themselves establish that A1C status causes differences in readmission risk.
--
-- The "Not recorded" category is retained rather than removed because missing
-- or unrecorded clinical information can itself be relevant to data-quality
-- and healthcare workflow analysis.

SELECT
    -- Display the A1C result category.
    a1cresult AS a1c_result,

    -- Count all encounters within each A1C category.
    COUNT(*) AS total_encounters,

    -- Count encounters that resulted in a 30-day readmission.
    SUM(readmitted_30d) AS readmitted_30d_encounters,

    -- Calculate the observed 30-day readmission rate.
    ROUND(
        100.0 * SUM(readmitted_30d)
        / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate_pct,

    -- Flag categories with fewer than 100 encounters.
    CASE
        WHEN COUNT(*) < 100 THEN 'Low volume'
        ELSE 'Higher volume'
    END AS volume_flag

-- Use the validated development cohort.
FROM staging.development_encounters

-- Create one result row for each A1C category.
GROUP BY a1cresult

-- Display the largest categories first.
ORDER BY total_encounters DESC;


-- =============================================================================
-- 13. KEY CLINICAL DATA-COMPLETENESS PROFILE
-- =============================================================================

-- Quantify how frequently important clinical fields contain explicitly
-- unrecorded or unavailable categories.
--
-- This is a data-quality analysis rather than a readmission-rate analysis.
--
-- The source dataset uses several different representations for unavailable
-- information, including:
--   "Not recorded"
--   "Unknown"
--   "Not Available"
--   "Not Mapped"
--
-- We preserve the source terminology instead of treating every form of
-- unavailable information as automatically equivalent.

SELECT
    -- Calculate the percentage of encounters without a recorded A1C result.
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE a1cresult = 'Not recorded'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS a1c_not_recorded_pct,

    -- Calculate the percentage of encounters without a recorded maximum
    -- glucose serum result.
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE max_glu_serum = 'Not recorded'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS max_glucose_not_recorded_pct,

    -- Calculate the percentage of encounters with an unknown payer code.
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE payer_code = 'Unknown'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS payer_unknown_pct,

    -- Calculate the percentage of encounters where medical specialty
    -- information is recorded as unknown.
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE medical_specialty = 'Unknown'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS specialty_unknown_pct,

    -- Calculate the percentage of encounters with an unknown race category.
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE race = 'Unknown'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS race_unknown_pct

-- Use the validated development cohort.
FROM staging.development_encounters;


-- =============================================================================
-- 14. UTILIZATION CHARACTERISTICS BY 30-DAY READMISSION OUTCOME
-- =============================================================================

-- Compare average utilization measures between encounters with and without
-- a 30-day readmission.
--
-- This analysis helps identify whether utilization-related variables show
-- different observed distributions across the binary target.
--
-- These results are descriptive associations only. A difference in averages
-- does not establish that a utilization measure causes readmission.
--
-- The same variables may later be evaluated as candidate predictors during
-- the machine-learning feature-engineering stage.

SELECT
    -- Display the binary target category.
    readmitted_30d AS readmitted_within_30_days,

    -- Count all encounters in each target category.
    COUNT(*) AS total_encounters,

    -- Calculate the average hospital length of stay.
    ROUND(
        AVG(time_in_hospital),
        2
    ) AS avg_length_of_stay,

    -- Calculate the average number of laboratory procedures.
    ROUND(
        AVG(num_lab_procedures),
        2
    ) AS avg_lab_procedures,

    -- Calculate the average number of procedures.
    ROUND(
        AVG(num_procedures),
        2
    ) AS avg_procedures,

    -- Calculate the average number of medications.
    ROUND(
        AVG(num_medications),
        2
    ) AS avg_medications,

    -- Calculate the average number of outpatient visits.
    ROUND(
        AVG(number_outpatient),
        2
    ) AS avg_outpatient_visits,

    -- Calculate the average number of emergency visits.
    ROUND(
        AVG(number_emergency),
        2
    ) AS avg_emergency_visits,

    -- Calculate the average number of prior inpatient visits.
    ROUND(
        AVG(number_inpatient),
        2
    ) AS avg_inpatient_visits,

    -- Calculate the average number of diagnoses.
    ROUND(
        AVG(number_diagnoses),
        2
    ) AS avg_diagnoses

-- Use the validated development cohort.
FROM staging.development_encounters

-- Create one summary row for each binary readmission outcome.
GROUP BY readmitted_30d

-- Display the non-readmitted group first, followed by the readmitted group.
ORDER BY readmitted_30d;
