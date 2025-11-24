-- ========================================
-- CREATE TABLES
-- ========================================

CREATE TABLE students (
    student_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    birth_date DATE
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8;

CREATE TABLE classes (
    class_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    teacher VARCHAR(100)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8;

CREATE TABLE enrollments (
    enrollment_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT,
    class_id INT,
    enrollment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (class_id) REFERENCES classes(class_id)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8;

-- ========================================
-- INSERT INITIAL DATA
-- ========================================

INSERT INTO students (first_name, last_name, birth_date) VALUES
('Alice', 'Smith', '2005-04-10'),
('Bob', 'Johnson', '2006-08-15'),
('Charlie', 'Brown', '2004-12-01');

INSERT INTO classes (name, teacher) VALUES
('Mathematics', 'Mrs. Taylor'),
('History', 'Mr. Anderson'),
('Science', 'Dr. Reynolds');

INSERT INTO enrollments (student_id, class_id) VALUES
(1, 1),
(1, 2),
(2, 2),
(3, 1),
(3, 3);

-- ========================================
-- SELECT: View all data after insert
-- ========================================

-- View all students
SELECT * FROM students;

-- View all classes
SELECT * FROM classes;

-- View all enrollments
SELECT * FROM enrollments;

-- View students enrolled in Mathematics
SELECT s.first_name, s.last_name
FROM students s
JOIN enrollments e ON s.student_id = e.student_id
JOIN classes c ON e.class_id = c.class_id
WHERE c.name = 'Mathematics';

-- Count students per class
SELECT c.name AS class_name, COUNT(e.student_id) AS student_count
FROM classes c
LEFT JOIN enrollments e ON c.class_id = e.class_id
GROUP BY c.name;

-- ========================================
-- UPDATE DATA
-- ========================================

UPDATE students
SET last_name = 'Williams'
WHERE first_name = 'Bob' AND last_name = 'Johnson';

UPDATE classes
SET teacher = 'Ms. Carter'
WHERE name = 'History';

-- ========================================
-- DELETE DATA
-- ========================================

DELETE FROM enrollments
WHERE student_id = (SELECT student_id FROM students WHERE first_name = 'Alice' AND last_name = 'Smith');

DELETE FROM students
WHERE first_name = 'Alice' AND last_name = 'Smith';

-- ========================================
-- AGGRESSIVE COMPRESSION METRIC CHURN
-- ========================================

-- Inspect buffer pool size (bytes)
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';

-- 1. Create a LARGE compressed table (bigger than buffer pool)
DROP TABLE IF EXISTS big_students;
CREATE TABLE big_students (
  id INT AUTO_INCREMENT PRIMARY KEY,
  pad1 VARCHAR(100),
  pad2 VARCHAR(100),
  notes TEXT,
  filler TEXT
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8;

-- 2. Create a LARGE uncompressed (eviction) table
DROP TABLE IF EXISTS evict_buffer;
CREATE TABLE evict_buffer (
  id INT AUTO_INCREMENT PRIMARY KEY,
  junk VARCHAR(100),
  blobdata TEXT
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

-- 3. Bulk insert rows into big_students (compressible data)
--    Adjust @rows_big upward (e.g. 2_000_000) if buffer pool is large.
SET @rows_big := 800000;

-- Insert in chunks using a numbers generator (10 x 10 x 10 x 8,000 expansion)
-- We construct ~@rows_big rows of highly compressible text.
INSERT INTO big_students (pad1, pad2, notes, filler)
SELECT
  CONCAT('P1_', n.seq),
  CONCAT('P2_', n.seq),
  RPAD('COMPRESSIBLE_', 1200, 'COMPRESSIBLE_'),
  RPAD('FILL', 800, 'FILL')
FROM (
  SELECT (@row := @row + 1) AS seq
  FROM
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t1,
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t2,
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t3,
    (SELECT @row := 0) init
  LIMIT @rows_big
) n;

-- 4. Bulk insert rows into evict_buffer (uncompressed & less compressible)
SET @rows_evict := 600000;
INSERT INTO evict_buffer (junk, blobdata)
SELECT
  CONCAT('J', n.seq),
  -- Less compressible pseudo-random-ish data (vary characters)
  CONCAT(
    MD5(RAND()), '_', MD5(RAND()), '_',
    RPAD(MD5(RAND()), 300, 'Z')
  )
FROM (
  SELECT (@row2 := @row2 + 1) AS seq
  FROM
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a,
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b,
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c,
    (SELECT @row2 := 0) init
  LIMIT @rows_evict
) n;

-- 5. Check row formats & sizes
SHOW TABLE STATUS LIKE 'big_students'\G
SHOW TABLE STATUS LIKE 'evict_buffer'\G

-- 6. Initial compression counters
SELECT PAGE_SIZE, COMPRESS_OPS, COMPRESS_TIME, UNCOMPRESS_OPS, UNCOMPRESS_TIME
FROM information_schema.INNODB_CMP;

-- 7. Workload procedures (interleaved access)
DELIMITER $$
CREATE PROCEDURE churn(IN loops INT)
BEGIN
  DECLARE i INT DEFAULT 0;
  DECLARE rstart INT;
  DECLARE dummy BIGINT;
  WHILE i < loops DO
    -- Random range read on compressed table (SQL_NO_CACHE)
    SET rstart = FLOOR(RAND() * @rows_big) + 1;
    SELECT /*+ SQL_NO_CACHE */ SUM(id) INTO dummy
    FROM big_students
    WHERE id BETWEEN rstart AND rstart + 150;

    -- Scan slice of eviction table to evict pages
    SET rstart = FLOOR(RAND() * @rows_evict) + 1;
    SELECT /*+ SQL_NO_CACHE */ COUNT(*) INTO dummy
    FROM evict_buffer
    WHERE id BETWEEN rstart AND rstart + 2000;

    -- Occasional full-ish scan segment to push more evictions
    IF (i % 50 = 0) THEN
      SELECT /*+ SQL_NO_CACHE */ AVG(id) INTO dummy
      FROM evict_buffer
      WHERE id BETWEEN rstart AND rstart + 25000;
    END IF;

    -- Update chunk on compressed table (forces page writes & reads)
    IF (i % 20 = 0) THEN
      UPDATE big_students
      SET filler = CONCAT(filler, 'X')
      WHERE id BETWEEN rstart AND rstart + 120;
    END IF;

    SET i = i + 1;
  END WHILE;
END$$
DELIMITER ;

-- 8. Run churn more than once (increase loops if needed)
CALL churn(2000);
CALL churn(2000);
CALL churn(3000);

-- 9. Re-check counters
SELECT PAGE_SIZE, COMPRESS_OPS, COMPRESS_TIME, UNCOMPRESS_OPS, UNCOMPRESS_TIME
FROM information_schema.INNODB_CMP;

-- 10. Optional: FORCE table rebuild (creates new compressed pages) then churn again
 ALTER TABLE big_students FORCE;
 CALL churn(3000);
 SELECT UNCOMPRESS_OPS, UNCOMPRESS_TIME FROM information_schema.INNODB_CMP;

