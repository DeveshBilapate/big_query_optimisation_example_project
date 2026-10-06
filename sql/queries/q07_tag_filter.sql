-- Monthly python questions in 2021 (filter on the first clustering column)
-- Years are shifted +16 for the BigQuery sandbox (2036 here = 2020 in the real data).
SELECT DATE_TRUNC(DATE(creation_date), MONTH) AS month,
       COUNT(*) AS questions, ROUND(AVG(score), 3) AS avg_score
FROM `so_bench.so_part_day_clust`
WHERE primary_tag = 'python'
  AND creation_date >= TIMESTAMP '2037-01-01' AND creation_date < TIMESTAMP '2038-01-01'
GROUP BY month
ORDER BY month
