-- ============================================================
-- Week 3: Building a Cohort with SQL (CTEs and Window Functions)
-- ============================================================
-- Database: synthetic_omop.duckdb (same companion file as Week 2)
-- Run with the DuckDB CLI, a SQL client, or from R/Python (see the
-- companion Week3_Cohort_R.qmd / Week3_Cohort_Python.ipynb files,
-- which run this same logic and pull the result into a dataframe).

-- ============================================================
-- PART 1: WALKTHROUGH
-- ============================================================

-- GOAL: build a cohort of patients with Type 2 Diabetes who started
-- metformin within 90 days of diagnosis, then calculate their age at
-- diagnosis and stratify by sex. This is a very common cohort-building
-- pattern in real observational research (new-user, first-line-treatment
-- cohorts).

-- Step 1: A Common Table Expression (CTE) — a named, temporary result set
-- you can reference later in the query. Think of it as a labeled scratchpad.
-- This CTE isolates everyone's Type 2 Diabetes diagnosis date.
WITH t2d_dx AS (
    SELECT person_id, condition_start_date AS diagnosis_date
    FROM condition_occurrence
    WHERE condition_concept_id = 101
)
SELECT * FROM t2d_dx LIMIT 5;

-- Step 2: A window function. Some patients might have more than one
-- metformin record (e.g., a refill). ROW_NUMBER() OVER (PARTITION BY ...)
-- lets us rank each patient's metformin exposures by date and pick out
-- just the first one, WITHOUT collapsing the rest of the table with GROUP BY.
WITH metformin_ranked AS (
    SELECT
        person_id,
        drug_exposure_start_date,
        ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY drug_exposure_start_date) AS rn
    FROM drug_exposure
    WHERE drug_concept_id = 201
)
SELECT * FROM metformin_ranked WHERE rn = 1 LIMIT 5;

-- Step 3: Chain multiple CTEs together, then join them to build the cohort.
-- Reading order: define each building block, then combine them in the final SELECT.
WITH t2d_dx AS (
    SELECT person_id, condition_start_date AS diagnosis_date
    FROM condition_occurrence
    WHERE condition_concept_id = 101
),
metformin_ranked AS (
    SELECT
        person_id,
        drug_exposure_start_date,
        ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY drug_exposure_start_date) AS rn
    FROM drug_exposure
    WHERE drug_concept_id = 201
),
first_metformin AS (
    SELECT person_id, drug_exposure_start_date AS metformin_start
    FROM metformin_ranked
    WHERE rn = 1
)
SELECT
    p.person_id,
    g.concept_name AS sex,
    t.diagnosis_date,
    f.metformin_start,
    DATE_DIFF('day', t.diagnosis_date, f.metformin_start) AS days_to_metformin,
    FLOOR((t.diagnosis_date - CAST((p.year_of_birth || '-01-01') AS DATE)) / 365.25) AS age_at_diagnosis
FROM t2d_dx t
JOIN first_metformin f ON f.person_id = t.person_id
JOIN person p ON p.person_id = t.person_id
LEFT JOIN concept g ON p.gender_concept_id = g.concept_id
WHERE f.metformin_start BETWEEN t.diagnosis_date AND t.diagnosis_date + INTERVAL 90 DAY;

-- Step 4: Stratify the cohort by sex.
WITH t2d_dx AS (
    SELECT person_id, condition_start_date AS diagnosis_date
    FROM condition_occurrence WHERE condition_concept_id = 101
),
metformin_ranked AS (
    SELECT person_id, drug_exposure_start_date,
        ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY drug_exposure_start_date) AS rn
    FROM drug_exposure WHERE drug_concept_id = 201
),
first_metformin AS (
    SELECT person_id, drug_exposure_start_date AS metformin_start FROM metformin_ranked WHERE rn = 1
),
cohort AS (
    SELECT
        p.person_id, g.concept_name AS sex,
        FLOOR((t.diagnosis_date - CAST((p.year_of_birth || '-01-01') AS DATE)) / 365.25) AS age_at_diagnosis
    FROM t2d_dx t
    JOIN first_metformin f ON f.person_id = t.person_id
    JOIN person p ON p.person_id = t.person_id
    LEFT JOIN concept g ON p.gender_concept_id = g.concept_id
    WHERE f.metformin_start BETWEEN t.diagnosis_date AND t.diagnosis_date + INTERVAL 90 DAY
)
SELECT sex, ROUND(AVG(age_at_diagnosis), 1) AS mean_age, COUNT(*) AS n
FROM cohort
GROUP BY sex;

-- A note on performance: on a real OMOP database (millions of rows), the
-- pattern above — filter early with WHERE, join only what you need, avoid
-- SELECT * — matters a lot. Indexes on person_id and concept_id columns
-- (already present in most CDM instances) make these joins fast even at scale.

-- ============================================================
-- PART 2: YOUR TURN (this week's deliverable)
-- ============================================================

-- Task 1: Modify the Step 3 query to build a similar cohort for patients
-- with Essential Hypertension (condition_concept_id = 102) who started
-- Lisinopril (drug_concept_id = 202) within 180 days of diagnosis.

-- Task 2: Stratify your Task 1 cohort by sex (like Step 4) and report the
-- mean age at diagnosis for each group.

-- Task 3: As a comment, explain in 2-3 sentences why we used a window
-- function (ROW_NUMBER) to find each patient's FIRST metformin exposure
-- instead of just taking the MIN(drug_exposure_start_date). (Hint: what
-- extra information does ROW_NUMBER give you access to that MIN() alone
-- doesn't?)

-- Submit this completed .sql file via the Week 3 dropbox, along with the
-- exported results of your Task 1/2 queries (CSV or screenshot). You'll
-- reuse this cohort logic in Week 4 to work with the same patients in
-- R and/or Python.
