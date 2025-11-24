-- ========================================
-- CREATE TABLES
-- ========================================

CREATE TABLE students (
    student_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(250),
    last_name VARCHAR(1000),
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
);

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
-- "HEAVY COMPRESSION METRIC BOOSTER" SECTION
-- Intensely stimulate compression & CPU load
-- ========================================

-- Add a much larger number of students (10,000)
INSERT INTO students (first_name, last_name, birth_date)
SELECT CONCAT('TestStudent', n), REPEAT('VeryLongSurname', 100), '2000-01-01'
FROM (
  SELECT @row := @row + 1 AS n FROM
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t1,
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t2,
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t3,
    (SELECT @row := 0) r
  LIMIT 10000
) big_numbers;

-- Add many classes with big teacher names (1,000)
INSERT INTO classes (name, teacher)
SELECT CONCAT('Class', n), REPEAT('TeacherLongNameExtra', 50)
FROM (
  SELECT @row := @row + 1 AS n FROM
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t1,
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t2,
    (SELECT @row := 0) r
  LIMIT 1000
) numbers;

-- Create 100,000 random enrollments
INSERT INTO enrollments (student_id, class_id)
SELECT FLOOR(1 + (RAND() * 10000)), FLOOR(1 + (RAND() * 1000))
FROM (
  SELECT @n := @n + 1 FROM
    (SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10) t1,
    (SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10) t2,
    (SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10) t3,
    (SELECT @n := 0) r
  LIMIT 100000
) massive_enrollments;

-- Heavy updates: repeatedly update many large records
UPDATE students
SET last_name = REPEAT('CPUSurnameOverload', 100)
WHERE student_id % 3 = 0;

UPDATE students
SET last_name = REPEAT('AnotherSurnamePattern', 120)
WHERE student_id % 7 = 0;

-- Massive class teacher name updates
UPDATE classes
SET teacher = REPEAT('VeryCPUIntensiveTeacher', 60)
WHERE class_id % 2 = 0;

UPDATE classes
SET teacher = REPEAT('XtremeTeacher', 80)
WHERE class_id % 3 = 0;

-- Heavy delete cycles to fragment and reorganize pages
DELETE FROM enrollments WHERE enrollment_id % 17 = 0;
DELETE FROM enrollments WHERE enrollment_id % 23 = 0;

-- Force additional storage engine work (optional, can be slow!!)
OPTIMIZE TABLE students;
OPTIMIZE TABLE classes;
OPTIMIZE TABLE enrollments;

-- Optional: Table scan SUMs to burn more CPU
SELECT SUM(CHAR_LENGTH(first_name) + CHAR_LENGTH(last_name)) FROM students;
SELECT SUM(CHAR_LENGTH(name) + CHAR_LENGTH(teacher)) FROM classes;
SELECT COUNT(*) FROM enrollments;

-- ========================================
-- End of heavy booster section
-- ========================================