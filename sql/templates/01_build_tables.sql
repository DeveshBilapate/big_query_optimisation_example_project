-- bigquery-cost-lab: build the table variants
-- Source: bigquery-public-data.stackoverflow.posts_questions (US multi-region)
-- Slice: 2012-01-01 .. 2021-12-31 = 3,653 days. A single query job can write at most
-- 4,000 partitions, so a full-history (2008-2022, ~5,100 days) daily-partitioned CTAS would fail.
-- We drop the huge `body` and `title` columns to stay well under the sandbox's 10 GB storage limit.
--
-- SANDBOX GOTCHA: the BigQuery sandbox forces partition_expiration_days = 60 on every
-- partitioned table (OPTIONS(partition_expiration_days = NULL) is silently overridden), so any
-- partition dated more than 60 days in the past is dropped the moment it's written - the
-- 2012-2021 copies come out EMPTY. Workaround: shift every date forward by 16 years
-- (a multiple of 4 keeps leap days, months and weekdays aligned). With billing enabled, use shift 0.

CREATE SCHEMA IF NOT EXISTS so_bench OPTIONS (location = 'US');

-- A: plain, unpartitioned, unclustered copy (the only statement that reads the public table)
CREATE OR REPLACE TABLE so_bench.so_raw AS
SELECT
  id,
  TIMESTAMP(DATETIME_ADD(DATETIME(creation_date), INTERVAL 16 YEAR)) AS creation_date,
  owner_user_id,
  tags,
  SPLIT(tags, '|')[SAFE_OFFSET(0)] AS primary_tag,
  score,
  view_count,
  answer_count,
  accepted_answer_id
FROM `bigquery-public-data.stackoverflow.posts_questions`
WHERE creation_date >= TIMESTAMP '2012-01-01'
  AND creation_date <  TIMESTAMP '2022-01-01';

-- B: partitioned by day
CREATE OR REPLACE TABLE so_bench.so_part_day
PARTITION BY DATE(creation_date)
AS SELECT * FROM so_bench.so_raw;

-- C: partitioned by day + clustered
CREATE OR REPLACE TABLE so_bench.so_part_day_clust
PARTITION BY DATE(creation_date)
CLUSTER BY primary_tag, owner_user_id
AS SELECT * FROM so_bench.so_raw;

-- D: partitioned by month + clustered (fewer, fatter partitions so clustering has room to work)
CREATE OR REPLACE TABLE so_bench.so_part_month_clust
PARTITION BY TIMESTAMP_TRUNC(creation_date, MONTH)
CLUSTER BY primary_tag, owner_user_id
AS SELECT * FROM so_bench.so_raw;

-- Sanity check: all four must report the same row count (an empty partitioned table means
-- partitions expired - see the sandbox note above). __TABLES__ is not used because its counts lag.
SELECT 'so_raw' AS table_name, COUNT(*) AS row_count FROM so_bench.so_raw
UNION ALL SELECT 'so_part_day', COUNT(*) FROM so_bench.so_part_day
UNION ALL SELECT 'so_part_day_clust', COUNT(*) FROM so_bench.so_part_day_clust
UNION ALL SELECT 'so_part_month_clust', COUNT(*) FROM so_bench.so_part_month_clust;
