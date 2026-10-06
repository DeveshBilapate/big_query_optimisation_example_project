-- Daily question counts for Q1 2020 (partition filter on the raw column)
-- Years are shifted +16 for the BigQuery sandbox (2036 here = 2020 in the real data).
SELECT DATE(creation_date) AS day, COUNT(*) AS questions
FROM `so_bench.so_part_day`
WHERE creation_date >= TIMESTAMP '2036-01-01' AND creation_date < TIMESTAMP '2036-04-01'
GROUP BY day
ORDER BY day
