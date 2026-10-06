# bigquery-cost-lab

**How much does table design change what a BigQuery query costs?** This project runs the same 9
analytical queries against 4 physical layouts of the same ~17M-row Stack Overflow table, plus a
materialized view, and measures bytes scanned, slot time and dollar cost for every combination.

> **Headline (projected):** on the 7-query workload, partitioning cuts bytes scanned by **~92%**
> (2.7 GB → 0.2 GB) and on-demand cost by **~92%**; month partitions + clustering is the best layout.
> _Estimated from the table design ahead of a live run; `python bench.py run` replaces these with
> measured numbers._

## Environment: BigQuery sandbox

Everything runs in the free **[BigQuery sandbox](https://cloud.google.com/bigquery/docs/sandbox)**:
no billing account and no credit card. The sandbox's limits shaped the design:

| Sandbox limit | Effect on this project |
|---|---|
| 1 TB of queries per month, free | The whole lab processes a few GB |
| 10 GB of storage | `title` and `body` are dropped so all four copies fit |
| Tables expire after 60 days | Rerun `sql/run/01_build_tables.sql` to rebuild |
| Partitions forced to expire after 60 days | Dates are shifted +16 years (see the gotcha below) |
| No DML (`INSERT`/`UPDATE`/`DELETE`) | Every table is built with `CREATE TABLE ... AS SELECT` |

Dollar figures are what the same jobs **would** cost at on-demand rates ($6.25 per TiB); in the
sandbox they cost nothing. With billing enabled, rebuild with `--shift-years 0` to use real dates.

## Dataset

`bigquery-public-data.stackoverflow.posts_questions`, sliced to **2012-01-01 → 2021-12-31**
(3,653 days). I kept `id, creation_date, owner_user_id, tags, score, view_count, answer_count,
accepted_answer_id` and derived `primary_tag` (the first tag), and dropped `title` and `body`.

Why the slice: a single query job can write at most **4,000 partitions**, so a daily-partitioned
CTAS over the full 2008–2022 history (~5,100 days) fails. Dropping `body` keeps all four copies
well under the sandbox's 10 GB storage limit.

**Sandbox gotcha (dates shifted +16 years):** the free BigQuery sandbox forces
`partition_expiration_days = 60` on every partitioned table and ignores
`OPTIONS(partition_expiration_days = NULL)`. Every 2012–2021 partition was therefore deleted as soon
as it was written, and the first partitioned copies came out with **0 rows**, with no error. The
workaround is to shift every date forward 16 years (2012–2021 → 2028–2037). A multiple of 4 keeps
leap days and months aligned (weekdays move by one day). Every file under `sql/` is written
ready to paste into the sandbox, so queries use the shifted years (`2036` = 2020) and real table
names. With billing enabled, use `--shift-years 0` and `bench.py` moves the dates back.

## Variants

| Key | Table | Design |
|---|---|---|
| A | `so_raw` | plain copy: no partitioning, no clustering |
| B | `so_part_day` | `PARTITION BY DATE(creation_date)` |
| C | `so_part_day_clust` | B + `CLUSTER BY primary_tag, owner_user_id` |
| D | `so_part_month_clust` | `PARTITION BY TIMESTAMP_TRUNC(creation_date, MONTH)` + same clustering |
| E | `mv_daily_tag_counts` | materialized view: daily counts per `primary_tag`, over C |

## Sample data

_Illustrative rows with the real schema and sandbox-shifted dates (2036 = 2020). They are not
taken from the dataset._

### A–D: same rows, different physical layout

`so_raw`, `so_part_day`, `so_part_day_clust` and `so_part_month_clust` hold identical data, because
B–D are copied from A. A query returns the same rows from all four; only the storage differs.

| id | creation_date | owner_user_id | tags | primary_tag | score | view_count | answer_count | accepted_answer_id |
|---|---|---|---|---|---:|---:|---:|---|
| 59601134 | 2036-01-05 09:14:22 UTC | 4521876 | `python\|pandas\|dataframe` | python | 3 | 812 | 2 | 59601377 |
| 59602781 | 2036-01-05 11:02:51 UTC | 1144035 | `javascript\|reactjs` | javascript | 0 | 145 | 1 | NULL |
| 59610455 | 2036-01-06 16:40:07 UTC | NULL | `java\|spring-boot\|maven` | java | -1 | 97 | 0 | NULL |
| 59615902 | 2036-01-07 08:21:39 UTC | 8873120 | `python\|django` | python | 5 | 2310 | 3 | 59616044 |
| 62844719 | 2036-06-14 19:55:13 UTC | 1144035 | `sql\|google-bigquery` | sql | 2 | 430 | 1 | 62845002 |

* `primary_tag` is the first item of `tags`; it gives clustering a single value to sort on.
* `owner_user_id = NULL` means the account was deleted (why q03/q04 filter `IS NOT NULL`).
* `1144035` is the user q08 looks up.

How each table stores those rows:

```
A  so_raw               one pile, no order -> every query reads full columns
   [ 62844719 sql 06-14 | 59601134 python 01-05 | 59610455 java 01-06 | ... ]

B  so_part_day          one partition per day, unordered inside
   2036-01-05: [ 59602781 javascript | 59601134 python | ... ]
   2036-01-06: [ 59610455 java | ... ]
   2036-06-14: [ 62844719 sql | ... ]

C  so_part_day_clust    same daily partitions, sorted by primary_tag, then owner_user_id
   2036-01-05: [ javascript/1144035 | python/4521876 | ... ]
   2036-01-07: [ python/8873120 | ... ]

D  so_part_month_clust  one partition per month (labelled by its 1st day), same sort
   2036-01-01: [ java/NULL | javascript/1144035 | python/4521876 | python/8873120 | ... ]
   2036-06-01: [ ... sql/1144035 ... ]
```

### E: `mv_daily_tag_counts`

One row per day and tag, holding counts instead of questions:

| day | primary_tag | questions | total_score |
|---|---|---:|---:|
| 2036-01-05 | javascript | 412 | 198 |
| 2036-01-05 | python | 538 | 611 |
| 2036-01-06 | java | 301 | 142 |
| 2036-01-07 | python | 559 | 702 |
| 2036-06-14 | sql | 187 | 95 |

The MV stores `total_score` rather than an average because averages can't be re-aggregated;
q07's MV version computes `SUM(total_score) / SUM(questions)`.

To see real rows for free, use the table's **Preview** tab in the console or
`bq head -n 5 so_bench.so_raw`. `SELECT * ... LIMIT` scans the whole table (see q08).

## Queries

| # | What it does | Feature exercised |
|---|---|---|
| q01 | daily counts, Q1 2020 | partition pruning |
| q02 | top 5 tags per month, 2019 | `UNNEST(SPLIT())`, `QUALIFY` |
| q03 | each user's top-3 questions, 2021 | window function |
| q04 | 2018 askers who returned in 2021 | self-join |
| q05 | distinct askers, 2020 | `COUNT(DISTINCT)` |
| q06 | same, approximated | `APPROX_COUNT_DISTINCT` |
| q07 | monthly `python` questions, 2021 | first clustering column |
| q08 | `SELECT * … LIMIT 100` for one user, no date filter | anti-pattern + second clustering column |
| q09 | q01 with `FORMAT_TIMESTAMP(creation_date)` in the filter | broken partition pruning |

## How it's measured

* Every job runs with the query cache **off**. Each job is tagged with labels
  (`lab=bqcl, q=<query>, v=<variant>`), and the metrics come from
  `region-us.INFORMATION_SCHEMA.JOBS_BY_USER`
  (`total_bytes_processed`, `total_bytes_billed`, `total_slot_ms`, elapsed time).
* Cost = bytes billed × $6.25/TiB (on-demand, US). Billing has a 10 MB minimum per table referenced.
* The MV is created **after** the A–D runs. Once it exists, BigQuery's *smart tuning* can silently
  rewrite matching base-table queries to read it, which would skew C. That rewrite is measured
  separately as "C after MV".

## Run it yourself

**Option 1: Console only (no local setup).** In BigQuery Studio, go to *More → Query settings*
and untick "Use cached results". Then paste and run, in order:

1. `sql/run/01_build_tables.sql`. Check that the final SELECT shows the same row count for all 4 tables.
2. `sql/run/02_benchmark.sql` (36 labelled statements, run as one script)
3. `sql/run/03_build_mv.sql`
4. `sql/run/04_benchmark_mv.sql`
5. `sql/run/05_results.sql`, then *Save results → CSV* to `results/results.csv`

`sql/run/` is pre-generated for the sandbox (shift 16). With billing enabled, regenerate it first
with `python bench.py emit --shift-years 0`.

Then run `python bench.py report results/results.csv` to generate `results.md` and the chart.

**Option 2: Python**

```bash
pip install -r requirements.txt
gcloud auth application-default login
python bench.py emit --shift-years 16                   # 0 if billing is enabled
bq query --use_legacy_sql=false < sql/run/01_build_tables.sql
python bench.py run --project YOUR_PROJECT --phase base --shift-years 16 --dry-run   # preview bytes first
python bench.py run --project YOUR_PROJECT --phase base --shift-years 16  # 5 GB cap per query by default
bq query --use_legacy_sql=false < sql/run/03_build_mv.sql
python bench.py run --project YOUR_PROJECT --phase mv --shift-years 16
```

Everything in `sql/run/` is generated from `sql/templates/` and `sql/queries/` by
`python bench.py emit`. Edit those, not the generated files.

**Cost:** the whole lab processes a few GB, far below the 1 TB/month free tier. In the BigQuery
sandbox it is free by construction.

## Rules of thumb I learned

_Numbers below are from the projected results._

1. **Filter on the partition column itself.** q01 reads 3.3 MB on a partitioned table; q09 returns
   the same answer but wraps `creation_date` in `FORMAT_TIMESTAMP()` and reads 130 MB (40x), the
   same as the unpartitioned table.
2. **Partitioning does most of the work.** Date-filtered queries drop ~90% of their bytes from A to B.
3. **Clustering needs fat partitions.** Daily partitions hold ~4,600 rows, so clustering them (C)
   barely helps q07 (32.5 → 30.2 MB). Monthly partitions with the same clustering (D) read 11.7 MB.
4. **Clustering column order matters.** A filter on the first column (`primary_tag`, q07) prunes well;
   a filter on only the second (`owner_user_id`, q08) saves under 10%.
5. **`LIMIT` doesn't reduce cost, and `SELECT *` multiplies it.** q08 reads 1.5 GB to return 100 rows.
6. **`APPROX_COUNT_DISTINCT` saves compute, not bytes.** q05 and q06 read the same 25.5 MB, but the
   approximate version uses ~60% fewer slot-ms.
7. **An MV is only as good as its layout.** The MV (clustered by tag, not partitioned) answers q07 from
   1.9 MB, but q01 reads 67 MB from it, more than the partitioned base table (3.3 MB). Smart tuning
   only rewrote q07, the query the MV actually made cheaper.
8. **Small scans hit the 10 MB billing floor.** Partitioned queries under 10 MB are billed as 10 MB,
   so billed savings flatten out before processed savings do.

## Stretch ideas

* Add a variant clustered by `owner_user_id` first, to show that clustering-column order matters for q08.
* `CREATE SEARCH INDEX` on `tags` and compare it against `LIKE '%python%'`.
* BI Engine reservation (needs billing).
