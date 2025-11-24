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
-- COMPRESSION METRIC BOOSTER (MINIMAL)
-- ========================================

-- 1. Confirm row format (should say "Compressed")
SHOW TABLE STATUS LIKE 'students'\G
SHOW TABLE STATUS LIKE 'classes'\G
SHOW TABLE STATUS LIKE 'enrollments'\G

-- 2. Add a compressible TEXT column (if not already present)
ALTER TABLE students ADD COLUMN notes TEXT NULL;

-- 3. Bulk-fill extra rows with highly compressible data
--    Adjust @rows if you want more.
SET @rows := 20000;

-- Build a numbers helper inline (100 x 200 = 20,000 rows)
INSERT INTO students (first_name, last_name, birth_date, notes)
SELECT CONCAT('Extra', n.seq)      AS first_name,
       CONCAT('User',  n.seq)      AS last_name,
       DATE('2005-01-01') + INTERVAL (n.seq % 365) DAY AS birth_date,
       RPAD('LoremIpsum ', 800, 'LoremIpsum ')         AS notes
FROM (
  SELECT (a.i*200) + b.i AS seq
  FROM (SELECT 0 i UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
  CROSS JOIN (
    SELECT 0 i UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
         UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14
         UNION ALL SELECT 15 UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
         UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23 UNION ALL SELECT 24
         UNION ALL SELECT 25 UNION ALL SELECT 26 UNION ALL SELECT 27 UNION ALL SELECT 28 UNION ALL SELECT 29
         UNION ALL SELECT 30 UNION ALL SELECT 31 UNION ALL SELECT 32 UNION ALL SELECT 33 UNION ALL SELECT 34
         UNION ALL SELECT 35 UNION ALL SELECT 36 UNION ALL SELECT 37 UNION ALL SELECT 38 UNION ALL SELECT 39
         UNION ALL SELECT 40 UNION ALL SELECT 41 UNION ALL SELECT 42 UNION ALL SELECT 43 UNION ALL SELECT 44
         UNION ALL SELECT 45 UNION ALL SELECT 46 UNION ALL SELECT 47 UNION ALL SELECT 48 UNION ALL SELECT 49
         UNION ALL SELECT 50 UNION ALL SELECT 51 UNION ALL SELECT 52 UNION ALL SELECT 53 UNION ALL SELECT 54
         UNION ALL SELECT 55 UNION ALL SELECT 56 UNION ALL SELECT 57 UNION ALL SELECT 58 UNION ALL SELECT 59
         UNION ALL SELECT 60 UNION ALL SELECT 61 UNION ALL SELECT 62 UNION ALL SELECT 63 UNION ALL SELECT 64
         UNION ALL SELECT 65 UNION ALL SELECT 66 UNION ALL SELECT 67 UNION ALL SELECT 68 UNION ALL SELECT 69
         UNION ALL SELECT 70 UNION ALL SELECT 71 UNION ALL SELECT 72 UNION ALL SELECT 73 UNION ALL SELECT 74
         UNION ALL SELECT 75 UNION ALL SELECT 76 UNION ALL SELECT 77 UNION ALL SELECT 78 UNION ALL SELECT 79
         UNION ALL SELECT 80 UNION ALL SELECT 81 UNION ALL SELECT 82 UNION ALL SELECT 83 UNION ALL SELECT 84
         UNION ALL SELECT 85 UNION ALL SELECT 86 UNION ALL SELECT 87 UNION ALL SELECT 88 UNION ALL SELECT 89
         UNION ALL SELECT 90 UNION ALL SELECT 91 UNION ALL SELECT 92 UNION ALL SELECT 93 UNION ALL SELECT 94
         UNION ALL SELECT 95 UNION ALL SELECT 96 UNION ALL SELECT 97 UNION ALL SELECT 98 UNION ALL SELECT 99
  ) b
  WHERE (a.i*200)+b.i < @rows
) n;

-- 4. View current compression counters
SELECT PAGE_SIZE, COMPRESS_OPS, COMPRESS_TIME, UNCOMPRESS_OPS, UNCOMPRESS_TIME
FROM information_schema.INNODB_CMP;

-- 5. Flush table metadata (does NOT guarantee eviction, but harmless)
FLUSH TABLE students;

-- 6. Workload generator: random range reads to stimulate uncompress
DELIMITER $$
CREATE PROCEDURE run_students_reads(IN loops INT)
BEGIN
  DECLARE i INT DEFAULT 0;
  DECLARE start_id INT;
  DECLARE dummy BIGINT;
  WHILE i < loops DO
    SET start_id = FLOOR(RAND()*@rows) + 1;
    -- Use SQL_NO_CACHE to skip the query cache (if enabled)
    SELECT /*+ SQL_NO_CACHE */ COUNT(*) INTO dummy
    FROM students
    WHERE student_id BETWEEN start_id AND start_id + 50;
    SET i = i + 1;
  END WHILE;
END$$
DELIMITER ;

CALL run_students_reads(5000);

-- 7. Check counters again
SELECT PAGE_SIZE, COMPRESS_OPS, COMPRESS_TIME, UNCOMPRESS_OPS, UNCOMPRESS_TIME
FROM information_schema.INNODB_CMP;

-- If still zero, optionally rebuild (forces new compressed pages) then re-run reads:
 ALTER TABLE students FORCE;
 CALL run_students_reads(8000);
 SELECT UNCOMPRESS_OPS, UNCOMPRESS_TIME FROM information_schema.INNODB_CMP;

