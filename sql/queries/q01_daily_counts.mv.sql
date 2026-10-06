-- Same answer as q01, read from the materialized view
-- Years are shifted +16 for the BigQuery sandbox (2036 here = 2020 in the real data).
SELECT day, SUM(questions) AS questions
FROM `so_bench.mv_daily_tag_counts`
WHERE day >= DATE '2036-01-01' AND day < DATE '2036-04-01'
GROUP BY day
ORDER BY day
