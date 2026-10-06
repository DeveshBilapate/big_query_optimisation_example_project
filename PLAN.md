# 1. `bigquery-cost-lab`: BigQuery partitioning and clustering benchmark

**Size:** 1 weekend · **Cost:** free (BigQuery sandbox, no credit card) · **Gaps closed:** BigQuery depth (#1, required in 68% of relevant jobs), SQL

## Idea
Prove with numbers that you know how to make BigQuery fast and cheap. Take a big public dataset,
run the same analytical queries against differently designed tables, and publish bytes scanned,
time and $ for each.

## Dataset
`bigquery-public-data.stackoverflow.posts_questions` (~20M rows), or
`bigquery-public-data.github_repos.commits`. **Careful:** github_repos is huge, so always preview
the "bytes processed" estimate before running, and stay under the 1 TB/month free query limit.

## Steps
1. Copy a slice into your own dataset as a plain table (`CREATE TABLE ... AS SELECT`).
2. Build variants: (a) unpartitioned, (b) partitioned by `DATE(creation_date)`,
   (c) partitioned and clustered by `tags`/`owner_user_id`, (d) a materialized view for a daily aggregate.
3. Write 6–8 realistic queries: daily counts, top tags per month, a window function (rank
   answers per user), a self-join, `APPROX_COUNT_DISTINCT` vs `COUNT(DISTINCT)`, an `ARRAY`/`UNNEST` on tags.
4. Run each query on each variant. Capture `total_bytes_processed` and `total_slot_ms` from
   `INFORMATION_SCHEMA.JOBS_BY_USER` into a results table.
5. A small Python script (`google-cloud-bigquery`) runs the benchmark and writes `results.md` plus a bar chart.
6. README: a results table, plus "rules of thumb I learned" (e.g. avoid `SELECT *`, filter on the partition column, clustering order matters).

## Stretch
- Partition pruning failing because of a function on the partition column (show the bad and the fixed query).
- Search indexes, or BI Engine reservation notes.

## Resume line
> Built a BigQuery benchmark on a 20M-row dataset; partitioning + clustering + materialized views cut bytes scanned by **X%** and query cost by **Y%** (Python, SQL).
