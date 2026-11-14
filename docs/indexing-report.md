# Indexing report

Baseline: `core` schema with indexes on primary keys, unique constraints, and
foreign-key columns only (`sql/transform/20_indexes.sql`). No index was chosen
for a query pattern yet — this report is the first deliberate one.

Method: `benchmarks/run_benchmarks.sh` wraps each query in
`EXPLAIN (ANALYZE, BUFFERS)`, keeps the full plan in `benchmarks/output/`, and
appends timings to `benchmarks/results.csv`. Labels `before` / `after` bracket
the index change in `benchmarks/index_experiments.sql`.

## The change

One index:

```sql
CREATE INDEX posts_questions_site_time
    ON core.posts (site, created_at)
    INCLUDE (answer_count)
    WHERE post_type_id = 1;
```

Three decisions in one line each:

- **Partial** (`WHERE post_type_id = 1`) — q01–q03 only ever read questions,
  so answers (roughly half the table) are excluded from the index entirely.
- **Leading columns `(site, created_at)`** — every question query aggregates
  per site over time, so the index is already in the order they consume.
- **`INCLUDE (answer_count)`** — q03 aggregates `answer_count`; carrying it as
  a non-key column keeps the index usable as an *index-only scan* without
  making the key wider.

Size: 6.3 MB against a 140 MB table.

## Results

| query | before (ms) | after (ms) | change |
|---|---:|---:|---|
| q01 questions per month | 344 | 114 | **3.0× faster** |
| q02 questions by hour | 350 | 146 | **2.4× faster** |
| q03 unanswered share | 268 | 145 | **1.9× faster** |
| q04 time to first answer | 622 | 609 | unchanged |
| q05 unanswered by tag | 239 | 248 | unchanged (noise) |

q01–q03 switch from `Seq Scan on posts` to
`Index Only Scan using posts_questions_site_time` — the table is never
touched. Full plans: `benchmarks/output/*_before.txt` vs `*_after.txt`.

## Where the index did nothing, and why that is correct

**q04 was the interesting case.** It self-joins questions to answers on
`parent_key` and aggregates the gap. The planner left both sides as parallel
sequential scans feeding a hash join, before *and* after the new index
existed. That is the right call: q04 reads a large fraction of the whole
table (every question that has an answer, plus every answer), so walking an
index row-by-row would be strictly slower than streaming the table. An index
helps when a query touches a small slice of a table; q04 touches most of it.

**q05 already had an index it ignores.** `post_tags(tag_key)` exists from the
foreign-key pass, and the plan still sequential-scans `post_tags` — because the
query aggregates over *all* tags, i.e. the whole table. Same lesson as q04:
an existing index being ignored is not a missing index, it is the planner
doing arithmetic correctly.

## What I take from this

- FK indexes exist for join lookup and constraint checking, not for analytics.
  Aggregation-heavy queries over half a table will not use them, and should not.
- The win came from matching the index to a *repeated access pattern*
  (questions-only, per site, over time), not from indexing a column that
  appeared in a `WHERE` clause once.
- Partial + covering indexes are cheap enough (6.3 MB) that a deliberate one
  beats a generic one, but the before/after measurement is what justifies
  keeping it. One run, one change, numbers kept.
