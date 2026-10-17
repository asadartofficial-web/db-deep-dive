# db-deep-dive

This is a database engineering project im building to learn relational modelling and get an idea for tech and data analysis in general. Coming from a BBA background, this is learning material at most [Not meant to be a product]

Currently loads Stack Exchange data dumps into PostgreSQL and models them into a typed analytical layer.

First project online, and the write-ups in `docs/` are a record of learnings (it shows my thought process and what I learned along the way and decisions I took)

## what it does

Stack Exchange publishes the full contents of each of its sites as XML. This pipeline takes three of them — coffee (small), gamedev (medium), gaming (large) — and;

1. loads them: XML is streamed to CSV, Bulk loaded to a staging tables per site where every column is `TEXT` so that nothing is rejected
2. models them: A `core` schema is built with real types, surrogate keys, foreign keys, indexes ; one set of tables covering all sites

The same code runs unchanged against the smallest site and the largest, a 48× difference in size. The data covers up to **31 March 2024**. The archive is labelled July 2024; that is the upload date, not the cut-off.

## Numbers

| layer | tables | rows |
|---|---|---|
| staging — raw, all `TEXT` | 27 | ~4.9M |
| `core` — typed and constrained | 8 | 4,772,300 |

14 foreign keys, 13 indexes, no violations on first apply.

## The schema

[Entity relationship diagram →](docs/erd.md)

Generated from the database catalogue, as to not drift away from the real constraints.

## How it is built

- One schema per site. `Posts.Id = 1` exists on all three sites, so a single shared table would make `id` meaningless. Each site gets its own namespace as the source has three independent ID spaces.

- `core` uses one schema with `site` as a column. Once surrogate keys are assigned the collisions stop existing, so the three sites merge into one set of tables and a cross-site comparison can be done by `GROUP BY`.

- Typing happens on the way out, not on the way in. Staging never rejects a row. A bad value can be queried before turning into a problem. Trying to fail loudly i think.

Full reasoning:
**[ingestion runbook](docs/ingestion-runbook.md)** ·
**[transform runbook](docs/transform-runbook.md)**

## Some decisions

- Tombstones created for deleted posts. Stack Exchange removes deleted posts from `Posts.xml` but keeps the votes and comments that referenced them, many of the votes point at nothing. The options were to drop those rows, leave the keys NULL, or insert placeholders. Dropping large amount of votes would bias every aggregate towards posts that survived moderation, so i chose place holders. There are 120,160 of them.

- `LEFT JOIN`, never `JOIN`, when resolving keys. An inner join drops rows that find no match without raising an error. It would return a smaller result that looks exactly like a correct one.

- `posts.tags` stays denormalised on purpose. The normalised form is `post_tags`. The original pipe-delimited string is kept beside it so any row can be traced back to the dump without a join.


## Some findings

**Posts with no identifiable author: 2.6% / 3.1% / 2.8%. Comments with no
identifiable author: 2.7% / 3.3% / 3.8%.** Different tables, different source
files, same answer. The agreement is what made me believe the number.

**Tag counts computed from the posts match Stack Exchange's own published counts
to 99.5%** — and the 0.5% that disagrees only ever goes one way, which points at
a cause rather than at noise. I have a hypothesis and no proof, and the runbook
says so.

**Votes carry no time of day.** Every one is stamped `00:00:00`, deliberately, so
a vote cannot be traced back to a voter. That rules out a whole class of analysis
permanently.

**gamedev uses 1,113 tags at 143 uses each; gaming uses 6,257 at 21 each.** Same
platform, opposite tagging cultures.

## A mistake worth recording

A mistyped command skipped one step of the user-tombstone pass. The next script
ran anyway, resolved 4,409 rows out of 4,410, and reported success. Nothing
failed. The only reason I noticed is that the typo itself produced a loud error
somewhere unrelated.

That is the failure mode this project taught me to watch for: a query that
returns the wrong answer and looks exactly like one that returned the right one.

## Running it

Requires PostgreSQL 18 and Python 3.14 with `psycopg2-binary`.

```powershell
# Survey a dump before trusting the column contract
python sql\seed\census.py ".\data\<Site>\*.xml" > docs\census-<site>.txt

# Build the staging schema, then parse and load
psql -U postgres -d stackexchange -v schema=<site> -f sql\seed\staging.sql
python sql\seed\parse_dump.py --all --site <Site>
python sql\seed\load_dump.py  --all --site <Site>
```

The transform layer runs in numbered order from `sql/transform/`. Full sequence
in the [transform runbook](docs/transform-runbook.md).

## What is not done

- **No marts layer.** `core` is modelled reality. Question-shaped tables sit on
  top of it and do not exist yet.
- **No incremental load.** Every script rebuilds. A second dump of the same site
  would need a full reload, not a merge.
- **Only foreign-key columns are indexed.** Performance indexing should follow
  real queries, and I have not written enough of those yet.
- **120 tag-uses remain unexplained.** Small, and documented rather than hidden.
- **The security and benchmarking work in the original plan is not started.**

## The data

Not in this repository. `data/` is gitignored and the dumps are not
redistributed here.

Stack Exchange content is licensed **CC BY-SA**. The dumps are available from the
Internet Archive community collections.

Example values shown in `docs/census-*.txt` are short excerpts of
user-contributed content from the Stack Exchange network, licensed CC BY-SA.
