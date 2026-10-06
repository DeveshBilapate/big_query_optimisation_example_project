# Results (projected)

_Projected results: estimated from the table design (row count, column sizes, partition sizes) ahead of a live run. `python bench.py run` replaces them with measured numbers._

MB = MiB processed (what on-demand billing charges for, before the 10 MB per-table minimum).

## Bytes processed (MB)

| Query | A: unpartitioned | B: partitioned (day) | C: day + clustered | D: month + clustered | E: MV |
|---|---:|---:|---:|---:|---:|
| `q01_daily_counts` | 130 | 3.3 | 3.3 | 3.3 | 67.1 |
| `q02_top_tags_per_month` | 618 | 56.2 | 56.2 | 56.2 | – |
| `q03_window_rank` | 520 | 41.6 | 41.6 | 41.6 | – |
| `q04_self_join` | 520 | 46.3 | 46.3 | 46.3 | – |
| `q05_count_distinct` | 260 | 25.5 | 25.5 | 25.5 | – |
| `q06_approx_count_distinct` | 260 | 25.5 | 25.5 | 25.5 | – |
| `q07_tag_filter` | 406 | 32.5 | 30.2 | 11.7 | 1.9 |
| `q08_select_star_user` | 1,545 | 1,545 | 1,498 | 1,390 | – |
| `q09_pruning_broken` | 130 | 130 | 130 | 130 | – |

## Slot time (slot-ms)

| Query | A: unpartitioned | B: partitioned (day) | C: day + clustered | D: month + clustered | E: MV |
|---|---:|---:|---:|---:|---:|
| `q01_daily_counts` | 2,850 | 420 | 395 | 410 | 1,150 |
| `q02_top_tags_per_month` | 18,400 | 3,950 | 3,880 | 3,720 | – |
| `q03_window_rank` | 21,300 | 6,840 | 6,610 | 6,550 | – |
| `q04_self_join` | 15,900 | 3,120 | 3,040 | 2,980 | – |
| `q05_count_distinct` | 9,800 | 2,450 | 2,380 | 2,360 | – |
| `q06_approx_count_distinct` | 4,100 | 980 | 950 | 940 | – |
| `q07_tag_filter` | 6,200 | 860 | 780 | 510 | 120 |
| `q08_select_star_user` | 7,900 | 8,400 | 7,600 | 6,900 | – |
| `q09_pruning_broken` | 3,100 | 4,250 | 4,300 | 3,350 | – |

## Realistic workload (q01-q07, 7 queries; q08/q09 are anti-pattern demos)

| Variant | MB processed | vs A | slot-ms | vs A | $ on-demand |
|---|---:|---:|---:|---:|---:|
| A: unpartitioned | 2,715 | 0.0% saved | 78,550 | 0.0% saved | $0.01621 |
| B: partitioned (day) | 231 | 91.5% saved | 18,620 | 76.3% saved | $0.00144 |
| C: day + clustered | 229 | 91.6% saved | 18,035 | 77.0% saved | $0.00142 |
| D: month + clustered | 210 | 92.3% saved | 17,470 | 77.8% saved | $0.00131 |

**Best layout: D: month + clustered**, 92% fewer bytes and 92% lower cost than the unpartitioned table.

## Materialized view

| Query | C before MV (MB) | E: query the MV (MB) | C after MV exists (MB) |
|---|---:|---:|---:|
| `q01_daily_counts` | 3.3 | 67.1 | 3.3 |
| `q07_tag_filter` | 30.2 | 1.9 | 1.9 |

If *C after MV exists* is much smaller than *C before MV*, BigQuery's smart tuning rewrote the base-table query to read the MV automatically.

## Partition pruning gotcha

Same result, same table (C): `q01` filters `creation_date` directly and scans **3.3 MB**; `q09` wraps it in `FORMAT_TIMESTAMP()` and scans **130 MB** (40x more).
