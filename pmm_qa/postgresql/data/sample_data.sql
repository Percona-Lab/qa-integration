-- Populate sample branches
INSERT INTO pgbench_branches (bid, bbalance, bname)
SELECT i, 100000, 'Branch ' || i
FROM generate_series(1, 10) AS i;

-- Populate sample tellers
INSERT INTO pgbench_tellers (tid, bid, tbalance, tname)
SELECT i, (i % 10) + 1, 10000, 'Teller ' || i
FROM generate_series(1, 50) AS i;

-- Populate sample accounts
INSERT INTO pgbench_accounts (aid, bid, abalance)
SELECT i, (i % 10) + 1, 1000
FROM generate_series(1, 10000) AS i;