-- =========================================================
-- InnoDB Compression Stress & Metrics Script (MySQL 8.4+)
-- =========================================================
-- Adjust these first if desired
SET @rows_per_table := 100000;      -- Base row count (increase for more stress)
SET @update_touch_fraction := 0.30; -- Fraction of rows to update (approx)
SET @delete_fraction := 0.10;       -- Fraction of rows to delete (approx)

-- Raise recursion depth for large CTE generation
SET SESSION cte_max_recursion_depth = 200000;

-- Drop & recreate schema
DROP DATABASE IF EXISTS innodb_compress_lab;
CREATE DATABASE innodb_compress_lab;
USE innodb_compress_lab;

-- Optional: ensure per-table tablespace (generally default ON now)
-- SHOW VARIABLES LIKE 'innodb_file_per_table';

-- =========================================================
-- Helper CTE for generating N numbers (1..@rows_per_table)
-- =========================================================
WITH RECURSIVE seq AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < @rows_per_table
)
SELECT COUNT(*) AS generated_rows INTO @generated_rows
FROM seq;
-- At this point seq can be re-used inside each INSERT ... SELECT (we'll redefine per table).

-- =========================================================
-- TABLE CREATION (different KEY_BLOCK_SIZE values)
-- =========================================================
-- Highly compressible: repeated patterns
CREATE TABLE t_comp_2 (
  id INT PRIMARY KEY AUTO_INCREMENT,
  compressible TEXT,
  semi_random TEXT
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=2;

CREATE TABLE t_comp_4 (
  id INT PRIMARY KEY AUTO_INCREMENT,
  compressible TEXT,
  semi_random TEXT
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=4;

CREATE TABLE t_comp_8 (
  id INT PRIMARY KEY AUTO_INCREMENT,
  compressible TEXT,
  semi_random TEXT
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8;

CREATE TABLE t_comp_16 (
  id INT PRIMARY KEY AUTO_INCREMENT,
  compressible TEXT,
  semi_random TEXT
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=16;

-- A mixed workload table (different patterns) reusing KEY_BLOCK_SIZE=8
CREATE TABLE t_mixed_8 (
  id INT PRIMARY KEY AUTO_INCREMENT,
  pattern_a TEXT,
  pattern_b TEXT,
  pattern_c TEXT
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8;

-- =========================================================
-- BEFORE METRICS SNAPSHOT
-- =========================================================
SELECT 'BEFORE' AS phase, * FROM information_schema.innodb_cmp ORDER BY page_size;

-- =========================================================
-- DATA LOAD SECTION
-- Each table: insert @rows_per_table rows with varied compressibility
-- =========================================================

-- Utility function via inline expressions:
-- compressible: REPEAT('A', 5000) + REPEAT('B', 5000) etc.
-- semi_random: CONCAT of pseudo-random fragments using MD5(RAND())

-- t_comp_2
WITH RECURSIVE seq AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < @rows_per_table
)
INSERT INTO t_comp_2 (compressible, semi_random)
SELECT
  CONCAT(REPEAT('A', 4000), REPEAT('B', 4000), REPEAT('C', 2000)),
  CONCAT(MD5(RAND()), MD5(RAND()), MD5(RAND()))
FROM seq;

-- t_comp_4
WITH RECURSIVE seq AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < @rows_per_table
)
INSERT INTO t_comp_4 (compressible, semi_random)
SELECT
  CONCAT(REPEAT('X', 3000), REPEAT('Y', 3000), REPEAT('Z', 4000)),
  CONCAT(MD5(RAND()), ':', MD5(RAND()), ':', MD5(RAND()))
FROM seq;

-- t_comp_8
WITH RECURSIVE seq AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < @rows_per_table
)
INSERT INTO t_comp_8 (compressible, semi_random)
SELECT
  REPEAT('LONGPATTERN1234567890', 600),  -- ~12000 chars compressible
  CONCAT(MD5(RAND()), MD5(RAND()), MD5(RAND()), MD5(RAND()))
FROM seq;

-- t_comp_16
WITH RECURSIVE seq AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < @rows_per_table
)
INSERT INTO t_comp_16 (compressible, semi_random)
SELECT
  REPEAT('QQQQQQQQQQ', 1500),  -- 15000 chars of repeated Q
  CONCAT(MD5(RAND()), '-', MD5(RAND()), '-', MD5(RAND()), '-', MD5(RAND()))
FROM seq;

-- t_mixed_8 (three distinct patterns)
WITH RECURSIVE seq AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < @rows_per_table
)
INSERT INTO t_mixed_8 (pattern_a, pattern_b, pattern_c)
SELECT
  REPEAT('M', 8000),
  CONCAT(REPEAT('N1', 2000), REPEAT('N2', 2000)),
  CONCAT(MD5(RAND()), REPEAT('R', 1000), MD5(RAND()))
FROM seq;

-- =========================================================
-- INTERMEDIATE METRICS (after inserts)
-- =========================================================
SELECT 'AFTER_INSERTS' AS phase, * FROM information_schema.innodb_cmp ORDER BY page_size;

-- =========================================================
-- HEAVY UPDATE CYCLES (touch ~30% of rows)
-- =========================================================
-- Use modulus predicates for approximate fractions

UPDATE t_comp_2
SET compressible = CONCAT(REPEAT('UPDATEDA', 3000), REPEAT('UPDATEDB', 3000))
WHERE id % 10 IN (0,1,2); -- ~30%

UPDATE t_comp_4
SET semi_random = CONCAT(MD5(RAND()), MD5(RAND()), REPEAT('UPD', 2000))
WHERE id % 10 IN (0,1,2);

UPDATE t_comp_8
SET compressible = REPEAT('UP8_', 4000)
WHERE id % 5 = 0;  -- 20%

UPDATE t_comp_16
SET semi_random = CONCAT(REPEAT('CHANGED', 1000), MD5(RAND()))
WHERE id % 4 = 0;  -- 25%

UPDATE t_mixed_8
SET pattern_b = REPEAT('REWRITEPATTERN', 3000)
WHERE id % 3 = 0;  -- ~33%

-- =========================================================
-- DELETE FRACTION (approx 10%) to cause page reorganizations
-- =========================================================
DELETE FROM t_comp_2   WHERE id % 10 = 0;
DELETE FROM t_comp_4   WHERE id % 10 = 0;
DELETE FROM t_comp_8   WHERE id % 10 = 0;
DELETE FROM t_comp_16  WHERE id % 10 = 0;
DELETE FROM t_mixed_8  WHERE id % 10 = 0;

-- =========================================================
-- OPTIMIZE TABLE (forces rebuild & compression) - optional & expensive
-- You can comment these out if runtime is too long.
-- =========================================================
OPTIMIZE TABLE t_comp_2;
OPTIMIZE TABLE t_comp_4;
OPTIMIZE TABLE t_comp_8;
OPTIMIZE TABLE t_comp_16;
OPTIMIZE TABLE t_mixed_8;

-- =========================================================
-- FINAL METRICS SNAPSHOT
-- =========================================================
SELECT 'FINAL' AS phase, * FROM information_schema.innodb_cmp ORDER BY page_size;

-- Focused view (selected columns)
SELECT 'FINAL_FOCUSED' AS phase,
       page_size, compress_ops, compress_time, uncompress_ops, uncompress_time
FROM information_schema.innodb_cmp
ORDER BY page_size;

-- =========================================================
-- OPTIONAL: Show table sizes
-- =========================================================
SELECT table_name,
       engine,
       row_format,
       DATA_LENGTH/1024/1024 AS data_mb,
       INDEX_LENGTH/1024/1024 AS index_mb,
       (DATA_LENGTH+INDEX_LENGTH)/1024/1024 AS total_mb
FROM information_schema.tables
WHERE table_schema='innodb_compress_lab'
ORDER BY total_mb DESC;

-- =========================================================
-- CLEANUP (uncomment if you want to drop everything at end)
-- =========================================================
-- DROP DATABASE innodb_compress_lab;