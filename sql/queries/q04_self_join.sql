-- Self-join: how many 2018 askers came back and asked again in 2021?
-- Years are shifted +16 for the BigQuery sandbox (2036 here = 2020 in the real data).
WITH y18 AS (
  SELECT DISTINCT owner_user_id FROM `so_bench.so_part_day`
  WHERE creation_date >= TIMESTAMP '2034-01-01' AND creation_date < TIMESTAMP '2035-01-01'
    AND owner_user_id IS NOT NULL
), y21 AS (
  SELECT DISTINCT owner_user_id FROM `so_bench.so_part_day`
  WHERE creation_date >= TIMESTAMP '2037-01-01' AND creation_date < TIMESTAMP '2038-01-01'
    AND owner_user_id IS NOT NULL
)
SELECT COUNT(*) AS returning_askers,
       (SELECT COUNT(*) FROM y18) AS askers_2018
FROM y18 JOIN y21 USING (owner_user_id)
