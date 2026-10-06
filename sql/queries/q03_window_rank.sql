-- Each user's top-3 questions of 2021 by score (window function), summarised
-- Years are shifted +16 for the BigQuery sandbox (2036 here = 2020 in the real data).
SELECT rnk, COUNT(*) AS questions, ROUND(AVG(score), 2) AS avg_score
FROM (
  SELECT owner_user_id, score,
         ROW_NUMBER() OVER (PARTITION BY owner_user_id ORDER BY score DESC, id) AS rnk
  FROM `so_bench.so_part_day`
  WHERE creation_date >= TIMESTAMP '2037-01-01' AND creation_date < TIMESTAMP '2038-01-01'
    AND owner_user_id IS NOT NULL
  QUALIFY rnk <= 3
)
GROUP BY rnk
ORDER BY rnk
