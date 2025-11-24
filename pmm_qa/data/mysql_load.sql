-- =========================================================
-- InnoDB Compression Stress & Metrics Script (MySQL 8.4+)
-- =========================================================
-- Adjust row count here (start smaller if resource constrained)
SET @rows_per_table := 100000;
SET @cte_depth := @rows_per_table + 10;  -- headroom for recursion
SET SESSION cte_max_recursion_depth = @cte_depth;

DROP DATABASE IF EXISTS innodb_compress_lab;
CREATE DATABASE innodb_compress_lab;
USE innodb_compress_lab;

-- Drop any leftover tables (defensive)
DROP TABLE IF EXISTS t_comp_2;
DROP TABLE IF EXISTS t_comp_4;
DROP TABLE IF EXISTS t_comp_8;
DROP TABLE IF EXISTS t_comp_16;
DROP TABLE IF EXISTS t_mixed_8;

-- =========================================================
-- Create compressed tables (classic InnoDB compression)
-- =========================================================
CREATE TABLE t_comp_2 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  compressible TEXT,
  semi_random TEXT
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=2;

CREATE TABLE t_comp_4 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  compressible TEXT,
  semi_random TEXT
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=4;

CREATE TABLE t_comp_8 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  compressible TEXT,
  semi_random TEXT
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8;

CREATE TABLE t_comp_16 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  compressible TEXT,
  semi_random TEXT
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=16;

CREATE TABLE t_mixed_8 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  pattern_a TEXT,
  pattern_b TEXT,
  pattern_c TEXT
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8;

-- =========================================================
-- Initial metrics snapshot
-- =========================================================
SELECT 'BEFORE' AS phase, ic.* FROM information_schema.innodb_cmp ic ORDER BY page_size;

-- =========================================================
-- Bulk Inserts (declare CTE separately for each table)
-- =========================================================

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
  REPEAT('LONGPATTERN1234567890', 600),  -- ~12k chars
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
  REPEAT('QQQQQQQQQQ', 1500),  -- 15k repeated Q
  CONCAT(MD5(RAND()), '-', MD5(RAND()), '-', MD5(RAND()), '-', MD5(RAND()))
FROM seq;

-- t_mixed_8
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
-- Metrics after inserts
-- =========================================================
SELECT 'AFTER_INSERTS' AS phase, ic.* FROM information_schema.innodb_cmp ic ORDER BY page_size;

-- =========================================================
-- Heavy updates (approx fractions via modular predicates)
-- =========================================================
UPDATE t_comp_2
SET compressible = CONCAT(REPEAT('UPDATEDA', 3000), REPEAT('UPDATEDB', 3000))
WHERE id % 10 IN (0,1,2);

UPDATE t_comp_4
SET semi_random = CONCAT(MD5(RAND()), MD5(RAND()), REPEAT('UPD', 2000))
WHERE id % 10 IN (0,1,2);

UPDATE t_comp_8
SET compressible = REPEAT('UP8_', 4000)
WHERE id % 5 = 0;

UPDATE t_comp_16
SET semi_random = CONCAT(REPEAT('CHANGED', 1000), MD5(RAND()))
WHERE id % 4 = 0;

UPDATE t_mixed_8
SET pattern_b = REPEAT('REWRITEPATTERN', 3000)
WHERE id % 3 = 0;

-- =========================================================
-- Deletes (~10%) to force page reorganization
-- =========================================================
DELETE FROM t_comp_2   WHERE id % 10 = 0;
DELETE FROM t_comp_4   WHERE id % 10 = 0;
DELETE FROM t_comp_8   WHERE id % 10 = 0;
DELETE FROM t_comp_16  WHERE id % 10 = 0;
DELETE FROM t_mixed_8  WHERE id % 10 = 0;

-- =========================================================
-- Optional: OPTIMIZE (expensive; triggers further compression)
-- Comment these out if runtime is excessive
-- =========================================================
OPTIMIZE TABLE t_comp_2;
OPTIMIZE TABLE t_comp_4;
OPTIMIZE TABLE t_comp_8;
OPTIMIZE TABLE t_comp_16;
OPTIMIZE TABLE t_mixed_8;

-- =========================================================
-- Final metrics snapshots
-- =========================================================
SELECT 'FINAL' AS phase, ic.* FROM information_schema.innodb_cmp ic ORDER BY page_size;

SELECT 'FINAL_FOCUSED' AS phase,
       ic.page_size,
       ic.compress_ops,
       ic.compress_time,
       ic.uncompress_ops,
       ic.uncompress_time
FROM information_schema.innodb_cmp ic
ORDER BY page_size;

-- Table size overview
SELECT table_name,
       engine,
       row_format,
       DATA_LENGTH/1024/1024 AS data_mb,
       INDEX_LENGTH/1024/1024 AS index_mb,
       (DATA_LENGTH+INDEX_LENGTH)/1024/1024 AS total_mb
FROM information_schema.tables
WHERE table_schema='innodb_compress_lab'
ORDER BY total_mb DESC;

-- Cleanup option (leave commented if you want to inspect)
-- DROP DATABASE innodb_compress_lab;