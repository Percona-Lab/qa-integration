-- ========================================
-- CREATE DB AND TABLES
-- ========================================
CREATE DATABASE IF NOT EXISTS school;
USE school;

DROP TABLE IF EXISTS enrollments;
DROP TABLE IF EXISTS students;
DROP TABLE IF EXISTS classes;

CREATE TABLE students (
    student_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name TEXT,
    last_name TEXT,
    birth_date DATE
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8;

CREATE TABLE classes (
    class_id INT AUTO_INCREMENT PRIMARY KEY,
    name TEXT,
    teacher TEXT
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

-- Insert 10,000 students with big names
INSERT INTO students (first_name, last_name, birth_date)
SELECT CONCAT('Student', n),
       REPEAT('Surname', 80),
       DATE_ADD('2000-01-01', INTERVAL RAND()*8000 DAY)
FROM (
    SELECT @n := @n + 1 AS n FROM
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL
     SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t1,
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL
     SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t2,
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL
     SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t3,
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL
     SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t4,
    (SELECT @n := 0) r
    LIMIT 10000
) numbers;

-- Insert 1000 classes with large teacher names
INSERT INTO classes (name, teacher)
SELECT CONCAT('Class', n),
       REPEAT('TeacherLongName', 80)
FROM (
    SELECT @n2 := @n2 + 1 AS n FROM
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL
     SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t1,
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL
     SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t2,
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL
     SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t3,
    (SELECT @n2 := 0) r
    LIMIT 1000
) numbers;

-- ========================================
-- CREATE A TEMPORARY HELPER TABLE FOR 100k ROWS
-- ========================================
DROP TEMPORARY TABLE IF EXISTS counter;
CREATE TEMPORARY TABLE counter (n INT PRIMARY KEY AUTO_INCREMENT) ENGINE=Memory;
INSERT INTO counter VALUES (NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL);
INSERT INTO counter(n) SELECT NULL FROM counter;   -- 10*10 = 100
INSERT INTO counter(n) SELECT NULL FROM counter;   -- 100*10 = 1,000
INSERT INTO counter(n) SELECT NULL FROM counter;   -- 1,000*10 = 10,000
INSERT INTO counter(n) SELECT NULL FROM counter;   -- 10,000*10 = 100,000

-- ========================================
-- BULK INSERT ENROLLMENTS (100,000 rows, all valid FKs)
-- ========================================
INSERT INTO enrollments (student_id, class_id)
SELECT
  (SELECT student_id FROM students ORDER BY RAND() LIMIT 1),
  (SELECT class_id FROM classes ORDER BY RAND() LIMIT 1)
FROM counter
LIMIT 100000;

DROP TEMPORARY TABLE counter;

-- ========================================
-- HEAVY UPDATES, DELETES, OPTIMIZE FOR CPU/COMPRESSION & PAGE CHANGE
-- ========================================

-- Bulk updates to make lots of compression work
UPDATE students
SET last_name = REPEAT('CPUSurnameOverload', 80)
WHERE student_id % 3 = 0;

UPDATE students
SET last_name = REPEAT('AnotherSurnamePattern', 80)
WHERE student_id % 5 = 0;

UPDATE classes
SET teacher = REPEAT('VeryCPUIntensiveTeacher', 40)
WHERE class_id % 2 = 0;

UPDATE classes
SET teacher = REPEAT('XtremeTeacher', 120)
WHERE class_id % 3 = 0;

-- Bulk delete for page re-org
DELETE FROM enrollments WHERE enrollment_id % 17 = 0;
DELETE FROM enrollments WHERE enrollment_id % 23 = 0;

-- Force flush/defrag pages (can be slow!)
OPTIMIZE TABLE students;
OPTIMIZE TABLE classes;
OPTIMIZE TABLE enrollments;

-- (Optional: Table scan SUMs to burn more CPU)
SELECT SUM(CHAR_LENGTH(first_name) + CHAR_LENGTH(last_name)) FROM students;
SELECT SUM(CHAR_LENGTH(name) + CHAR_LENGTH(teacher)) FROM classes;
SELECT COUNT(*) FROM enrollments;

-- ========================================
-- END OF SCRIPT
-- ========================================