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
-- AGGRESSIVE COMPRESSION METRIC CHURN (Chunked)
-- ========================================

-- Inspect buffer pool (bytes)
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';

DROP TABLE IF EXISTS big_students;
CREATE TABLE big_students (
  id INT AUTO_INCREMENT PRIMARY KEY,
  pad1 VARCHAR(100),
  pad2 VARCHAR(100),
  notes TEXT,
  filler TEXT
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8;

DROP TABLE IF EXISTS evict_buffer;
CREATE TABLE evict_buffer (
  id INT AUTO_INCREMENT PRIMARY KEY,
  junk VARCHAR(100),
  blobdata TEXT
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

-- How many total rows you want (adjust upward if buffer pool is large)
SET @rows_big   := 800000;  -- compressed table target
SET @rows_evict := 600000;  -- eviction table target

-- We will insert in CHUNKS of 50,000 rows to avoid huge single INSERT
SET @chunk_size := 50000;

-- Helper: make small number tables (0..99) and (0..499) for expansion
DROP TEMPORARY TABLE IF EXISTS nums100;
CREATE TEMPORARY TABLE nums100 (n INT PRIMARY KEY);
INSERT INTO nums100(n)
SELECT seq FROM (
  SELECT 0 AS seq UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
  UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
) d1,
(
  SELECT 0 AS seq UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
  UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
) d2;  -- 10 x 10 = 100

DROP TEMPORARY TABLE IF EXISTS nums500;
CREATE TEMPORARY TABLE nums500 (n INT PRIMARY KEY);
INSERT INTO nums500(n)
SELECT seq FROM (
  SELECT 0 AS seq UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
  UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
) d1,
(
  SELECT 0 AS seq UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
  UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
) d2,
(
  SELECT 0 AS seq UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
  UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
) d3,
(
  SELECT 0 AS seq UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
  UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
) d4,
(
  SELECT 0 AS seq UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
  UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
) d5; -- 10^5 = 100000 (we will LIMIT to 500 per 100 => 50000 rows per chunk)

-- Procedure to load big_students in chunks
DELIMITER $$
CREATE PROCEDURE fill_big_students(IN total INT, IN chunk INT)
BEGIN
  DECLARE inserted INT DEFAULT 0;
  WHILE inserted < total DO
    INSERT INTO big_students (pad1, pad2, notes, filler)
    SELECT
      CONCAT('P1_', seq + inserted) AS pad1,
      CONCAT('P2_', seq + inserted) AS pad2,
      RPAD('COMPRESSIBLE_', 1200, 'COMPRESSIBLE_') AS notes,
      RPAD('FILL', 800, 'FILL') AS filler
    FROM (
      SELECT (a.n * 500) + b.n AS seq
      FROM nums100 a
      JOIN nums500 b ON b.n < 500   -- ensures 100 * 500 = 50,000 rows
    ) gen
    LIMIT chunk;
    SET inserted = inserted + chunk;
  END WHILE;
END$$
DELIMITER ;

-- Procedure to load evict_buffer in chunks (less compressible data)
DELIMITER $$
CREATE PROCEDURE fill_evict_buffer(IN total INT, IN chunk INT)
BEGIN
  DECLARE inserted INT DEFAULT 0;
  WHILE inserted < total DO
    INSERT INTO evict_buffer (junk, blobdata)
    SELECT
      CONCAT('J', seq + inserted),
      CONCAT(MD5(RAND()), '_', MD5(RAND()), '_', RPAD(MD5(RAND()), 300, 'Z'))
    FROM (
      SELECT (a.n * 500) + b.n AS seq
      FROM nums100 a
      JOIN nums500 b ON b.n < 500
    ) gen
    LIMIT chunk;
    SET inserted = inserted + chunk;
  END WHILE;
END$$
DELIMITER ;

-- Execute loaders
CALL fill_big_students(@rows_big, @chunk_size);
CALL fill_evict_buffer(@rows_evict, @chunk_size);

-- Verify formats
SHOW TABLE STATUS LIKE 'big_students'\G
SHOW TABLE STATUS LIKE 'evict_buffer'\G

-- Initial compression counters
SELECT PAGE_SIZE, COMPRESS_OPS, COMPRESS_TIME, UNCOMPRESS_OPS, UNCOMPRESS_TIME
FROM information_schema.INNODB_CMP;

-- Churn procedure (interleaved access)
DELIMITER $$
CREATE PROCEDURE churn(IN loops INT)
BEGIN
  DECLARE i INT DEFAULT 0;
  DECLARE rstart INT;
  DECLARE dummy BIGINT;
  WHILE i < loops DO
    SET rstart = FLOOR(RAND() * @rows_big) + 1;
    SELECT SQL_NO_CACHE SUM(id) INTO dummy
    FROM big_students
    WHERE id BETWEEN rstart AND rstart + 150;

    SET rstart = FLOOR(RAND() * @rows_evict) + 1;
    SELECT SQL_NO_CACHE COUNT(*) INTO dummy
    FROM evict_buffer
    WHERE id BETWEEN rstart AND rstart + 3000;

    IF (i % 40 = 0) THEN
      SELECT SQL_NO_CACHE AVG(id) INTO dummy
      FROM evict_buffer
      WHERE id BETWEEN rstart AND rstart + 30000;
    END IF;

    IF (i % 25 = 0) THEN
      UPDATE big_students
      SET filler = CONCAT(filler, 'X')
      WHERE id BETWEEN rstart AND rstart + 180;
    END IF;

    SET i = i + 1;
  END WHILE;
END$$
DELIMITER ;

-- Run multiple passes (increase loops if needed)
CALL churn(3000);
CALL churn(3000);
CALL churn(4000);

-- Check counters again
SELECT PAGE_SIZE, COMPRESS_OPS, COMPRESS_TIME, UNCOMPRESS_OPS, UNCOMPRESS_TIME
FROM information_schema.INNODB_CMP;

-- Optional: FORCE rebuild to create fresh compressed pages and churn again
-- ALTER TABLE big_students FORCE;
-- CALL churn(4000);
-- SELECT UNCOMPRESS_OPS, UNCOMPRESS_TIME FROM information_schema.INNODB_CMP;
