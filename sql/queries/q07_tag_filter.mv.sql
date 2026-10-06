-- Same answer as q07, read from the materialized view
-- Years are shifted +16 for the BigQuery sandbox (2036 here = 2020 in the real data).
SELECT DATE_TRUNC(day, MONTH) AS month,
       SUM(questions) AS questions, ROUND(SUM(total_score) / SUM(questions), 3) AS avg_score
FROM `so_bench.mv_daily_tag_counts`
WHERE primary_tag = 'python'
  AND day >= DATE '2037-01-01' AND day < DATE '2038-01-01'
GROUP BY month
ORDER BY month
