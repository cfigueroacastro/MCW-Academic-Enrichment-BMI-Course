-- ============================================================
-- Week 2: Exploring the OMOP Common Data Model
-- ============================================================
-- Database: synthetic_omop.duckdb (companion file — same folder)
--
-- HOW TO RUN THIS FILE:
--   Option A (DuckDB CLI):      duckdb synthetic_omop.duckdb < week2_omop_exploration.sql
--   Option B (interactively):   duckdb synthetic_omop.duckdb   then paste queries one at a time
--   Option C (GUI client):      open synthetic_omop.duckdb in DBeaver or a similar SQL client
--                                that supports DuckDB, and run statements one at a time.
--
-- This is a small, hand-built teaching database shaped exactly like the real
-- OMOP CDM (same table and column names), but with a tiny 20-row vocabulary
-- instead of the full Athena vocabulary (which has millions of concepts).
-- The query patterns below are identical to what you'd use on a real OMOP
-- database like Eunomia, Synthea, or an actual OHDSI network node.

-- ============================================================
-- PART 1: WALKTHROUGH
-- ============================================================

-- Step 1: See what tables exist in this database.
SHOW TABLES;

-- Step 2: Inspect the Person table — the OMOP CDM's "hub" table.
-- Every clinical event (a condition, a drug, a lab result) links back to a person_id.
SELECT * FROM person LIMIT 5;

-- Step 3: Notice gender and race are stored as concept_id integers, not text.
-- This is the core idea of a standardized vocabulary: instead of one hospital
-- writing "M", another "Male", and another "1", OMOP maps everything to a
-- single reference concept_id, defined once in the concept table.
SELECT * FROM concept WHERE domain_id = 'Gender';

-- Step 4: Join Person to Concept to get human-readable values.
SELECT
    p.person_id,
    g.concept_name AS gender,
    p.year_of_birth,
    r.concept_name AS race
FROM person p
LEFT JOIN concept g ON p.gender_concept_id = g.concept_id
LEFT JOIN concept r ON p.race_concept_id = r.concept_id
LIMIT 10;

-- Step 5: Explore Condition_Occurrence the same way.
SELECT
    co.condition_occurrence_id,
    co.person_id,
    c.concept_name AS condition,
    co.condition_start_date
FROM condition_occurrence co
JOIN concept c ON co.condition_concept_id = c.concept_id
LIMIT 10;

-- Step 6: Top conditions by number of occurrences.
-- (This teaching dataset only has 6 distinct conditions, but the query
-- pattern is exactly what you'd run on a real OMOP database with hundreds.)
SELECT
    c.concept_name AS condition,
    COUNT(*) AS n_occurrences
FROM condition_occurrence co
JOIN concept c ON co.condition_concept_id = c.concept_id
GROUP BY c.concept_name
ORDER BY n_occurrences DESC
LIMIT 10;

-- ============================================================
-- PART 2: YOUR TURN (this week's deliverable)
-- ============================================================

-- Task 1: Write a query that returns the top 10 medications
-- (Drug_Exposure joined to Concept) by number of occurrences,
-- mirroring the pattern in Step 6.


-- Task 2: Write a query that counts how many DISTINCT patients
-- (not occurrences) have each condition. Hint: COUNT(DISTINCT person_id).
-- Note: in this particular synthetic dataset, no patient has the same
-- condition recorded twice, so your Task 2 numbers may look identical
-- to Step 6's numbers. On real clinical data, where patients accumulate
-- repeat diagnoses and visits over time, these two counts usually diverge.


-- Task 3: As a SQL comment (below), explain in 2-3 sentences the
-- difference between "number of occurrences" and "number of distinct
-- patients," and why that distinction matters when analyzing real
-- clinical data.
-- (write your answer here)


-- Submit this completed .sql file via the Week 2 dropbox in Brightspace.
-- If your SQL client can export results, also attach the output of your
-- two queries as a CSV or screenshot.
