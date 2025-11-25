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
-- BIG COMPRESSED TABLES FOR LOAD GENERATION
-- ========================================

CREATE TABLE IF NOT EXISTS students_big (
  id INT AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(50),
  last_name  VARCHAR(50),
  birth_date DATE,
  bio TEXT,
  notes TEXT,
  filler VARBINARY(256),
  INDEX (last_name),
  INDEX (birth_date)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8;

CREATE TABLE IF NOT EXISTS students_big2 LIKE students_big;
ALTER TABLE students_big2 ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=4;

CREATE TABLE IF NOT EXISTS students_small (
  id INT AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(50),
  last_name  VARCHAR(50),
  birth_date DATE,
  INDEX (last_name)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8;

-- Seed 200k rows (run once). If already done, skip.
INSERT INTO students_big (first_name, last_name, birth_date, bio, notes, filler)
SELECT
  CONCAT('FN', LPAD(i, 6, '0')),
  CONCAT('LN', LPAD(i*13 % 1000000, 6, '0')),
  DATE_ADD('1970-01-01', INTERVAL (i*37 % 18628) DAY),
  REPEAT('BIO_', 50),
  REPEAT('NOTE_', 30),
  RANDOM_BYTES(256)
FROM (
  SELECT @row := @row + 1 AS i
  FROM (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t0,
       (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t1,
       (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t2,
       (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t3,
       (SELECT @row:=0) init
) gen
LIMIT 200000;

INSERT INTO students_big2
SELECT * FROM students_big;

INSERT INTO students_small (first_name, last_name, birth_date)
SELECT first_name, last_name, birth_date FROM students_big LIMIT 200000;

-- ========================================
-- EVENT TO GENERATE CONTINUOUS COMPRESSION WORK
-- ========================================

-- Make sure the event scheduler is on:
SET GLOBAL event_scheduler = ON;

-- Change delimiter to allow compound statement
DELIMITER //

DROP EVENT IF EXISTS ev_compress_load//

CREATE EVENT ev_compress_load
ON SCHEDULE EVERY 5 SECOND
ON COMPLETION PRESERVE
DO
BEGIN
  -- Inserts (~2k rows per run)
  INSERT INTO students_big (first_name, last_name, birth_date, bio, notes, filler)
  SELECT
    CONCAT('FNX', UUID()),
    CONCAT('LNX', UUID()),
    DATE_ADD('1970-01-01', INTERVAL FLOOR(RAND()*18628) DAY),
    REPEAT('BIO_', FLOOR(20 + RAND()*60)),
    REPEAT('NOTE_', FLOOR(10 + RAND()*40)),
    RANDOM_BYTES(256)
  FROM information_schema.columns
  LIMIT 2000;

  -- Updates (touch pages)
  UPDATE students_big
  SET bio   = CONCAT(bio, 'U'),
      notes = CONCAT(notes, 'U')
  WHERE id % 37 = 0
  LIMIT 2000;

  -- Deletes (free space for merges)
  DELETE FROM students_big
  WHERE id % 101 = 0
  LIMIT 1000;

  -- Periodic re-compression
  IF (UNIX_TIMESTAMP() % 60) < 5 THEN
    OPTIMIZE TABLE students_big;
    OPTIMIZE TABLE students_big2;
  END IF;
END//

DELIMITER ;

-- ========================================
-- VERIFICATION QUERIES
-- ========================================
-- Check that event is created and enabled
SHOW EVENTS LIKE 'ev_compress_load';

-- Check a few rows
SELECT COUNT(*) FROM students_big;