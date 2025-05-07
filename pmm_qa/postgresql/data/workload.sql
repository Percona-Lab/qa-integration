-- begin a transaction
BEGIN;

-- simulate user account lookup
SELECT abalance
FROM pgbench_accounts
WHERE aid = :aid;

-- simulate joining branch and teller info
SELECT b.bid, b.bname, t.tid, t.tname
FROM pgbench_branches b
JOIN pgbench_tellers t ON b.bid = t.bid
WHERE b.bid = :bid AND t.tid = :tid;

-- conditional balance transfer
UPDATE pgbench_accounts
SET abalance = abalance - :delta
WHERE aid = :aid AND abalance >= :delta;

-- deposit to another account
UPDATE pgbench_accounts
SET abalance = abalance + :delta
WHERE aid = :aid + 1;

-- insert transaction log
INSERT INTO pgbench_history (tid, bid, aid, delta, mtime)
VALUES (:tid, :bid, :aid, :delta, CURRENT_TIMESTAMP);

COMMIT;