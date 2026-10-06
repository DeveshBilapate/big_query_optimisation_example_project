-- Exact distinct askers in 2020
-- Years are shifted +16 for the BigQuery sandbox (2036 here = 2020 in the real data).
SELECT COUNT(DISTINCT owner_user_id) AS askers
FROM `so_bench.so_part_day`
WHERE creation_date >= TIMESTAMP '2036-01-01' AND creation_date < TIMESTAMP '2037-01-01'
