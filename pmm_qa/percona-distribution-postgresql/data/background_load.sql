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
(3, 'Charlie', 'charlie@example.com');

-- Step 3: Query the data
SELECT * FROM test_users;

-- Step 4: Delete the data
DELETE FROM test_users;

-- Step 5: Drop the table
DROP TABLE test_users;
