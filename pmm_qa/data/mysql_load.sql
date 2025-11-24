-- ========================================
-- "COMPRESSION METRIC BOOSTER" SECTION
-- Add heavy bulk-inserts and updates to trigger compression ops/timings
-- ========================================

-- Add more students with large fields to fill compressed pages
INSERT INTO students (first_name, last_name, birth_date)
SELECT CONCAT('TestFirst', n), REPEAT('LongSurname', 10), '2000-01-01'
FROM (
    SELECT @row := @row + 1 AS n FROM
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t1,
    (SELECT @row := 0) r
    LIMIT 1000
) numbers;

-- Add classes with big teacher names
INSERT INTO classes (name, teacher)
SELECT CONCAT('Class', n), REPEAT('TeacherLongName', 10)
FROM (
    SELECT @row := @row + 1 AS n FROM
    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t1,
    (SELECT @row := 0) r
    LIMIT 100
) numbers;

-- Create a large number of enrollments randomly
INSERT INTO enrollments (student_id, class_id)
SELECT FLOOR(1 + (RAND() * 1000)), FLOOR(1 + (RAND() * 100))
FROM (SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10) t1,
     (SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10) t2;

-- Additional updates to trigger further compression activity
UPDATE students
SET last_name = REPEAT('Surname', 15)
WHERE student_id <= 500;

UPDATE classes
SET teacher = REPEAT('DrLongTeacherSurname', 8)
WHERE class_id <= 50;

-- Optionally, delete some records to cause page reorganization/compression
DELETE FROM enrollments
WHERE enrollment_id % 7 = 0;

-- Optionally, compress fragmented pages further
OPTIMIZE TABLE students;
OPTIMIZE TABLE classes;
OPTIMIZE TABLE enrollments;

-- ========================================
-- End of booster section
-- ========================================