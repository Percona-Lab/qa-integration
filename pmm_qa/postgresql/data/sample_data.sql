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