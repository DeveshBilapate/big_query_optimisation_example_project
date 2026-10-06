-- Top 5 tags per month in 2019 (ARRAY / UNNEST + QUALIFY)
-- Years are shifted +16 for the BigQuery sandbox (2036 here = 2020 in the real data).
WITH t AS (
  SELECT DATE_TRUNC(DATE(creation_date), MONTH) AS month, tag
  FROM `so_bench.so_part_day`, UNNEST(SPLIT(tags, '|')) AS tag
  WHERE creation_date >= TIMESTAMP '2035-01-01' AND creation_date < TIMESTAMP '2036-01-01'
)
SELECT month, tag, COUNT(*) AS n
FROM t
GROUP BY month, tag
QUALIFY ROW_NUMBER() OVER (PARTITION BY month ORDER BY COUNT(*) DESC) <= 5
ORDER BY month, n DESC
