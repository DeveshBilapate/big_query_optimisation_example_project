-- Anti-pattern: SELECT * + LIMIT, filtered on the SECOND clustering column, no date filter
SELECT *
FROM `so_bench.so_part_day_clust`
WHERE owner_user_id = 1144035
LIMIT 100
