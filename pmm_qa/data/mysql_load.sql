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
-- AGGRESSIVE COMPRESSION METRIC CHURN (Stable Version)
-- ========================================

-- 0. (Optional) Verify buffer pool size; use it to size tables
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';

-- 1. Drop if exist
DROP TABLE IF EXISTS big_students;
DROP TABLE IF EXISTS evict_buffer;

-- 2. Create large compressed table
CREATE TABLE big_students (
  id INT AUTO_INCREMENT PRIMARY KEY,
  pad1 VARCHAR(100),
  pad2 VARCHAR(100),
  notes TEXT,
  filler TEXT
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8;

-- 3. Create large dynamic (uncompressed) eviction table
CREATE TABLE evict_buffer (
  id INT AUTO_INCREMENT PRIMARY KEY,
  junk VARCHAR(100),
  blobdata TEXT
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

-- 4. Configuration knobs (adjust as needed)
SET @rows_big   := 800000;   -- target rows in compressed table
SET @rows_evict := 600000;   -- target rows in eviction table
SET @chunk_size := 50000;    -- rows per batch insert (must divide cleanly into generation set: 100*500=50,000)
SET @note_pad   := 1200;     -- length of compressible notes
SET @fill_pad   := 800;      -- length of filler column

-- 5. Helper number tables (nums100: 0..99, nums500: 0..499)
DROP TEMPORARY TABLE IF EXISTS nums100;
CREATE TEMPORARY TABLE nums100 (n INT PRIMARY KEY) ENGINE=Memory;
SET @i := 0;
WHILE @i < 100 DO
  INSERT INTO nums100 VALUES (@i);
  SET @i := @i + 1;
END WHILE;

DROP TEMPORARY TABLE IF EXISTS nums500;
CREATE TEMPORARY TABLE nums500 (n INT PRIMARY KEY) ENGINE=Memory;
SET @i := 0;
WHILE @i < 500 DO
  INSERT INTO nums500 VALUES (@i);
  SET @i := @i + 1;
END WHILE;

-- 6. Procedures for chunked loading (no ambiguous aliases)
DELIMITER $$
CREATE PROCEDURE fill_big_students(IN total INT, IN chunk INT)
BEGIN
  DECLARE inserted INT DEFAULT 0;
  WHILE inserted < total DO
    INSERT INTO big_students (pad1, pad2, notes, filler)
    SELECT
      CONCAT('P1_', inserted + a.n * 500 + b.n),
      CONCAT('P2_', inserted + a.n * 500 + b.n),
      RPAD('COMPRESSIBLE_', @note_pad, 'COMPRESSIBLE_'),
      RPAD('FILL', @fill_pad, 'FILL')
    FROM nums100 a
    JOIN nums500 b
    LIMIT chunk;
    SET inserted = inserted + chunk;
  END WHILE;
END$$

CREATE PROCEDURE fill_evict_buffer(IN total INT, IN chunk INT)
BEGIN
  DECLARE inserted INT DEFAULT 0;
  WHILE inserted < total DO
    INSERT INTO evict_buffer (junk, blobdata)
    SELECT
      CONCAT('J', inserted + a.n * 500 + b.n),
      CONCAT(MD5(RAND()), '_', MD5(RAND()), '_', RPAD(MD5(RAND()), 300, 'Z'))
    FROM nums100 a
    JOIN nums500 b
    LIMIT chunk;
    SET inserted = inserted + chunk;
  END WHILE;
END$$
DELIMITER ;

-- 7. Execute loaders
CALL fill_big_students(@rows_big, @chunk_size);
CALL fill_evict_buffer(@rows_evict, @chunk_size);

-- 8. Verify row formats
SHOW TABLE STATUS LIKE 'big_students'\G
SHOW TABLE STATUS LIKE 'evict_buffer'\G

-- 9. Baseline compression counters
SELECT PAGE_SIZE, COMPRESS_OPS, COMPRESS_TIME, UNCOMPRESS_OPS, UNCOMPRESS_TIME
FROM information_schema.INNODB_CMP;

-- 10. Churn procedure (interleaved reads/writes)
DELIMITER $$
CREATE PROCEDURE churn(IN loops INT)
BEGIN
  DECLARE i INT DEFAULT 0;
  DECLARE rstart INT;
  DECLARE dummy BIGINT;
  WHILE i < loops DO
    -- Random range read on compressed table
    SET rstart = FLOOR(RAND() * @rows_big) + 1;
    SELECT SQL_NO_CACHE SUM(id) INTO dummy
    FROM big_students
    WHERE id BETWEEN rstart AND rstart + 150;

    -- Eviction range read
    SET rstart = FLOOR(RAND() * @rows_evict) + 1;
    SELECT SQL_NO_CACHE COUNT(*) INTO dummy
    FROM evict_buffer
    WHERE id BETWEEN rstart AND rstart + 3000;

    -- Larger slice to push more buffer churn
    IF (i % 40 = 0) THEN
      SELECT SQL_NO_CACHE AVG(id) INTO dummy
      FROM evict_buffer
      WHERE id BETWEEN rstart AND rstart + 30000;
    END IF;

    -- Update segment in compressed table (write + possible read)
    IF (i % 25 = 0) THEN
      UPDATE big_students
      SET filler = CONCAT(filler, 'X')
      WHERE id BETWEEN rstart AND rstart + 180;
    END IF;

    SET i = i + 1;
  END WHILE;
END$$
DELIMITER ;

-- 11. Run churn passes (raise loops if needed)
CALL churn(3000);
CALL churn(3000);
CALL churn(4000);

-- 12. Re-check counters
SELECT PAGE_SIZE, COMPRESS_OPS, COMPRESS_TIME, UNCOMPRESS_OPS, UNCOMPRESS_TIME
FROM information_schema.INNODB_CMP;

-- 13. Optional: Rebuild & churn again to create fresh compressed pages
-- ALTER TABLE big_students FORCE;
-- CALL churn(4000);
-- SELECT UNCOMPRESS_OPS, UNCOMPRESS_TIME FROM information_schema.INNODB_CMP;

-- 14. Optional reset (for repeated experiments)
-- SELECT * FROM information_schema.INNODB_CMP_RESET;
-- TRUNCATE TABLE information_schema.INNODB_CMP_RESET;
