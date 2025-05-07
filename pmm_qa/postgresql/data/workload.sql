\set aid random(1, 10000)
\set delta random(-100, 100)
\set bid random(1, 10)
\set tid random(1, 50)

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'pgbench_branches'
      AND column_name = 'bname'
  ) THEN
    ALTER TABLE pgbench_branches ADD COLUMN bname TEXT DEFAULT 'Branch';
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'pgbench_tellers'
      AND column_name = 'tname'
  ) THEN
    ALTER TABLE pgbench_tellers ADD COLUMN tname TEXT DEFAULT 'Teller';
  END IF;
END$$;

BEGIN;

SELECT abalance
  FROM pgbench_accounts
 WHERE aid = :aid;

SELECT b.bid, b.bname, t.tid, t.tname
  FROM pgbench_branches b
  JOIN pgbench_tellers t ON b.bid = t.bid
 WHERE b.bid = :bid AND t.tid = :tid;

UPDATE pgbench_accounts
   SET abalance = abalance - :delta
 WHERE aid = :aid AND abalance >= :delta;

UPDATE pgbench_accounts
   SET abalance = abalance + :delta
 WHERE aid = :aid + 1;

INSERT INTO pgbench_history (tid, bid, aid, delta, mtime)
VALUES (:tid, :bid, :aid, :delta, CURRENT_TIMESTAMP);

COMMIT;