-- Same answer as q01, but wrapping the partition column in a function defeats pruning
-- Years are shifted +16 for the BigQuery sandbox (2036 here = 2020 in the real data).
SELECT DATE(creation_date) AS day, COUNT(*) AS questions
FROM `so_bench.so_part_day_clust`
WHERE FORMAT_TIMESTAMP('%Y-%m', creation_date) BETWEEN '2036-01' AND '2036-03'
GROUP BY day
ORDER BY day
