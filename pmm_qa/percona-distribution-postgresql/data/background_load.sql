-- Step 1: Create a test table
CREATE TABLE test_users (
    id INT PRIMARY KEY,
    name VARCHAR(50),
    email VARCHAR(100)
);

-- Step 2: Insert test data
INSERT INTO test_users (id, name, email) VALUES
(1, 'Alice', 'alice@example.com'),
(2, 'Bob', 'bob@example.com'),
(3, 'Charlie', 'charlie@example.com'),
(4, 'David', 'david@example.com'),
(5, 'Eva', 'eva@example.com'),
(6, 'Frank', 'frank@example.com'),
(7, 'Grace', 'grace@example.com'),
(8, 'Hannah', 'hannah@example.com'),
(9, 'Ian', 'ian@example.com'),
(10, 'Julia', 'julia@example.com'),
(11, 'Kevin', 'kevin@example.com'),
(12, 'Laura', 'laura@example.com'),
(13, 'Mike', 'mike@example.com'),
(14, 'Nina', 'nina@example.com'),
(15, 'Oscar', 'oscar@example.com'),
(16, 'Paula', 'paula@example.com'),
(17, 'Quentin', 'quentin@example.com'),
(18, 'Rachel', 'rachel@example.com'),
(19, 'Steve', 'steve@example.com'),
(20, 'Tina', 'tina@example.com');

-- Step 3: Query the data
SELECT * FROM test_users;

-- Step 4: Delete the data
DELETE FROM test_users;

-- Step 5: Drop the table
DROP TABLE test_users;
