-- Pull the benchmark metrics from job history (labels were set by the benchmark scripts).
-- Price: on-demand US is $6.25 per TiB billed; first 1 TiB per month is free.
SELECT
  (SELECT value FROM UNNEST(labels) WHERE key = 'q') AS query,
  (SELECT value FROM UNNEST(labels) WHERE key = 'v') AS variant,
  total_bytes_processed,
  total_bytes_billed,
  total_slot_ms,
  TIMESTAMP_DIFF(end_time, start_time, MILLISECOND) AS elapsed_ms,
  ROUND(total_bytes_billed / POW(1024, 4) * 6.25, 6) AS cost_usd,
  cache_hit
FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_USER
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)
  AND EXISTS (SELECT 1 FROM UNNEST(labels) WHERE key = 'lab' AND value = 'bqcl')
  AND statement_type = 'SELECT'
  AND state = 'DONE'
  AND error_result IS NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY query, variant ORDER BY creation_time DESC) = 1
ORDER BY query, variant;
