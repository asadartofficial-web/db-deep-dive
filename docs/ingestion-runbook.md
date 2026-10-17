# Ingestion runbook

How raw Stack Exchange XML becomes rows in `<site>.staging_*`, and the decisions
behind it.

**Status: working end to end across three sites** as of 2026-09-28. ~4.9 million
rows in 27 tables, all counts matching their censuses.

## The shape

```
data/<Site>/<Table>.xml  --parse_dump.py-->  data/<Site>/<staging_table>.csv  --load_dump.py-->  <site>.staging_<table>
                                |                                                    |
                                +------------ sql/seed/dump_schema.py ---------------+
                                              (one column contract)
```

| File | Role |
|---|---|
| `census.py` | Surveys a dump: which attributes exist, how often, how big. Run first, on any new dump. |
| `dump_schema.py` | The contract. Pure data: kept columns, offloaded text, ignored attributes, renames. |
| `parse_dump.py` | XML → CSV, streaming. Aborts on unclassified attributes. |
| `staging.sql` | Hand-written DDL, run once per schema. |
| `load_dump.py` | CSV → Postgres via `COPY FROM STDIN`, whole run in one transaction. |

No code outside `dump_schema.py` knows the name of a single Stack Exchange attribute.

## Environment

- PostgreSQL **18.6**, `C:\Program Files\PostgreSQL\18\bin` on PATH
- Database `stackexchange`, user `postgres`
- Python 3.14, `psycopg2-binary`
- Dumps in per-site subfolders: `data/coffee/`, `data/Gamedev/`, `data/Gaming/`

Per-site subfolders matter because a single-site dump extracts as bare XML files
with no containing folder, and every site's files have identical names.

Raw data stays out of the repo; `.gitignore` covers `data/`, `*.xml`, `*.7z`,
`*.csv`. The dump licence excludes redistribution.

## One schema per site

Each site gets its own Postgres schema holding the same nine tables:
`coffee.staging_posts`, `gamedev.staging_posts`, `gaming.staging_posts` are three
separate tables that share a short name.

**Why.** `Posts.Id = 1` exists in all three sites. In one shared table, `id` stops
identifying a row and the real key becomes `(site, id)` — which forces composite
foreign keys and makes every join silently wrong if the site predicate is
forgotten. Staging mirrors the source, and the source has three independent ID
spaces, so staging has three namespaces.

**Why not a `site` column at this layer.** That is the right answer for the typed
layer, where surrogate keys are assigned and `id` collisions stop existing. At the
staging layer it would buy composite keys and a silent-join hazard for no gain.

**Why fully qualified names rather than `search_path` in Python.** `TRUNCATE
staging_posts` is correct only because of a `SET` that ran earlier on the same
connection; if that didn't happen the name silently resolves to `public` and the
wrong table is truncated. `TRUNCATE gamedev.staging_posts` cannot fall back — a
wrong schema is "relation does not exist", a crash rather than data loss. Same
principle as naming every column in `COPY` and as the drift check: prefer the
failure mode that stops. `staging.sql` still uses `search_path`, which is safe
because psql runs that file top to bottom in one visible session.

**Schema name validation.** `schema` is the only identifier in the pipeline that
comes from the command line rather than the committed contract, so `load_dump.py`
checks it against `re.fullmatch(r"[a-z_][a-z0-9_]*", schema)` — an allowlist, and
`fullmatch` rather than `match` so a trailing `; DROP …` cannot slip past a
partial match. Not a meaningful defence against someone who already has the
password; it is the habit you want when the input arrives from further away.

## Decisions

**ELT with all-TEXT staging.** No primary keys, no `NOT NULL`, no foreign keys.
Staging never rejects a row. Typing happens on the way *out*, where a bad value is
a query you can inspect rather than a load that dies at 2am on row 4,000,000.

**Table-driven parser, not one script per table.** One parser plus a config,
rather than six copy-pasted scripts or runtime attribute discovery. The config is
hand-owned; the census supplies the evidence.

**`keep` vs `ignore`, not just `keep`.** Anything in neither list is drift worth
stopping for. `set(attrib) - classified(table)` runs on every row.

**`PostHistory` excluded.** 44% of coffee's dump, 51% of Gamedev's, 49% of
Gaming's — roughly 1.4 GB across the three — for a table that only answers
questions about edit history. It also gives bytes rather than rows: at 847,297
rows in Gaming it is half the size of `Votes`.

**Wide text offloaded, two tables only.** `Posts.Body` and `Users.AboutMe` go to
`staging_posts_text` and `staging_users_text`. `Comments.Text` is capped at 600
characters by Stack Exchange — below the ~2 KB TOAST threshold, so it never moves
out of line anyway.

**Offload rows skipped when the text is empty**, so the side tables hold fewer
rows than their parents and queries need a `LEFT JOIN`.

**`*UserId` and `*DisplayName` both kept, never merged.** One is a reference, one
is a value. Coalescing belongs in a view.

**Rare attributes ignored, not deleted.** `Votes.UserId`, `Votes.BountyAmount`,
`Posts.FavoriteCount`, `Posts.CommunityOwnedDate`.

**Three renames.** `Badges.Date` → `awarded_date`, `Tags.Count` → `post_count`,
`Comments.Text` → `comment_text`, all to avoid collisions with Postgres type and
function names.

## The dump is dated twice, and the two dates are four months apart

The archive is **published 2024-07-04**. The **data stops 2024-03-31**. The latest
row in every gamedev table falls on 31 March 2024.

Quote 2024-03-31 as the period the data covers. The July date describes when
somebody uploaded the files, not when the export was cut. Anyone reading only the
archive name would state the wrong period by a third of a year.

## The drift check has not fired yet — and that is not proof

All three sites have **identical attribute sets**: 6 / 7 / 10 / 5 / 22 / 5 / 12 / 6
for Badges, Comments, PostHistory, PostLinks, Posts, Tags, Users, Votes.

All three dumps came from the same exporter at the same cut-off, so there was
nothing for the check to catch. Schema drift lives across dump *dates*, not across
sites. A genuine test would be a 2019 dump against this contract, where
`FavoriteCount` was standard and `ContentLicense` did not exist.

What the three-site run *did* prove: the pipeline handles 1.68 million rows in one
table and a 286 MB `Posts.xml` with no code changes and flat memory.

## Verified loads — 2026-09-28

| table | coffee | gamedev | gaming |
|---|---|---|---|
| `staging_posts` | 4,525 | 139,830 | 272,959 |
| `staging_posts_text` | 4,486 | 139,502 | 271,395 |
| `staging_users` | 11,594 | 138,982 | 212,535 |
| `staging_users_text` | 5,340 | 47,291 | 51,499 |
| `staging_comments` | 4,985 | 235,411 | 336,601 |
| `staging_votes` | 22,128 | 546,061 | 1,682,904 |
| `staging_badges` | 14,615 | 240,874 | 449,569 |
| `staging_tags` | 114 | 1,113 | 6,257 |
| `staging_post_links` | 622 | 10,033 | 23,864 |
| **total** | **68,409** | **1,499,097** | **3,307,583** |

Every count matches `docs/census-<site>.txt`. The two `_text` tables are
deliberately lower than their parents — empty-string bodies and About Mes.

## Findings across the three sites

**Profile completion falls as a community grows.** Three independent optional
fields, same direction, across an 18× size range:

| | users | AboutMe | Location | WebsiteUrl |
|---|---|---|---|---|
| coffee | 11,594 | 46.6% | 47.1% | 26.3% |
| gamedev | 138,982 | 35.9% | 42.7% | 24.7% |
| gaming | 212,535 | 25.6% | 26.5% | 18.3% |

**Answers per question varies by site**: coffee 1.96, gamedev 1.44, gaming 1.62.
And `PostTypeId` is never binary — 1.1% to 3.4% of posts are neither question nor
answer (tag wikis, moderator nominations).

Note: `docs/transform-runbook.md` reports 1.78 / 1.40 / 1.50 for the same measure.
The denominators differ — these figures divide by `PostTypeId = 1`, those divide
by all non-answers. Neither is wrong; neither should be quoted without saying
which.

**`Votes` carries no time of day.** All 546,061 gamedev votes are stamped exactly
`00:00:00`, across the whole range from 2008-08-29 to 2024-03-31. Stack Exchange
strips the time from `Votes.xml` on purpose: a precise vote timestamp would
identify the voter. Hour-of-day and day-part analysis is possible on posts and
comments. It is permanently impossible on votes. This is a property of the source,
not a defect in the pipeline, and no amount of reloading will change it.

**`Users.AccountId` is not always populated**: 0 missing in coffee, 3 in gamedev,
6 in gaming. It scales with size, so it is systematic. Check before making it a
`NOT NULL` foreign key.

**Rare-attribute frequencies move between sites.** `FavoriteCount` 0.6% → 0.9% →
1.2%; `CommunityOwnedDate` 0.3% → 1.4% → 0.3%.

**`Posts.Body` max exceeds `PostHistory.Text` max** on every site (40,283 vs
29,968 in Gaming). `PostHistory.Text` is the markdown source, capped at Stack
Exchange's 30,000-character limit; `Body` is the rendered HTML, which is longer
because the tags are added afterwards.

**Presence is not the same as non-empty.** The census counts an attribute as
present whenever the name appears, so `Body` reads 100% while 39 / 328 / 1,564
rows across the three sites carry `Body=""`.

**`Users.Id` starts at `-1`** on every site — the Community system account.

**`Users.AccountId` and `Users.Id` are different ID spaces** — network-wide versus
site-local, never joinable to each other.

**The files may not be a single atomic snapshot — suspected, not proven.**
`Tags.xml` reports 120 more tag-uses across 87 tags than the same tags get when
counted from `Posts.xml`, and never fewer. A one-directional gap of that shape is
what a few dozen posts deleted between two export moments would produce.
`docs/transform-runbook.md` holds the figures. No test has confirmed it, and the
obvious test — comparing latest timestamps per file — measures last activity, not
export time, so it cannot settle the question.

## The census extensions, and why they are deferred

Two improvements were raised. Neither is built, and both decisions are deliberate.

**Splitting "absent" from "present-but-empty".** Real gap, measured by hand
instead: 39 / 328 / 1,564 rows carry `Body=""`. The census exists to inform the
contract; the contract is written and has survived three sites unchanged.
Reporting the split automatically would change nothing downstream now.

**`census.py --suggest`, to propose a contract from census evidence.** This should
not be built as designed. Rare-attribute frequencies move between sites —
`FavoriteCount` 0.6% → 0.9% → 1.2%, `CommunityOwnedDate` 0.3% → 1.4% → 0.3%. Any
threshold rule would classify the same attribute differently per site. A tool that
*proposes* is defensible; one that *decides* would be wrong. That is a conclusion,
not a missing feature.

Both become worth revisiting the day a new dump arrives — a different site, or an
older export. Then the census runs against an unknown shape, and the contract
decision is open again.

## Running it

```powershell
# 1. Survey a new dump before trusting the contract.
python sql\seed\census.py ".\data\<Site>\*.xml" > docs\census-<site>.txt

# 2. Build the schema and its nine tables (destructive: drops and recreates).
psql -U postgres -d stackexchange -v schema=<site> -f sql\seed\staging.sql

# 3. Parse and load.
python sql\seed\parse_dump.py --all --site <Site>
python sql\seed\load_dump.py  --all --site <Site>

# Inspect the COPY statements without connecting:
python sql\seed\load_dump.py Posts --site <Site> --print-sql
```

Verify the schemas exist with nine tables each:

```sql
SELECT table_schema, count(*) AS tables
FROM information_schema.tables
WHERE table_schema IN ('coffee','gamedev','gaming')
GROUP BY table_schema ORDER BY table_schema;
```

`load_dump.py` prints a row count per table; compare against the census. The whole
run is one transaction — a failure anywhere rolls back everything.

## Connection settings

`load_dump.py` reads `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`,
falling back to `localhost:5432/stackexchange` as `postgres` and prompting for the
password if `PGPASSWORD` is unset. No credentials in the repo.

## One security note

`f"TRUNCATE {table}"` interpolates straight into SQL — the exact shape of an
injection bug. It is safe because the table name comes from the contract and the
schema name is validated against an allowlist. Parameterised queries protect
*values*; identifiers cannot be parameterised, so they must come from a trusted
source or a validated pattern.

## What happens next

Staging is the source mirrored faithfully. The typed layer is reality modelled,
and it is built — see `docs/transform-runbook.md` for `core`, its eight tables,
the tombstone and key-resolution passes, and the constraint work.

## Key words

**ELT** — Extract, Load, Transform. Raw data lands in the warehouse first and is
reshaped there with SQL, as opposed to ETL where it is reshaped before loading.

**Schema (Postgres)** — a namespace inside a database, between the database and
its tables. `public` is the default; unqualified names resolve through
`search_path`.

**Surrogate key** — a key the warehouse generates (`BIGSERIAL`) rather than one
inherited from the source. It is what makes three colliding ID spaces coexist in
one table.

**TOAST** — The Oversized-Attribute Storage Technique. Postgres pages are 8 KB and
a row cannot span two, so values pushing a row past roughly 2 KB are compressed and
moved to a side table.

**Schema drift** — when the structure of incoming data changes without the pipeline
being told. Silent drift is the usual cause of columns that quietly stop being
populated.

**Allowlist** — validation that states what is permitted and rejects everything
else, as opposed to a denylist that tries to enumerate what is forbidden. Finite
versus infinite.

## References

- Stack Exchange data dump schema — https://meta.stackexchange.com/questions/2677/database-schema-documentation-for-the-public-data-dump-and-sede
- Postgres schemas and `search_path` — https://www.postgresql.org/docs/current/ddl-schemas.html
- Postgres `COPY` — https://www.postgresql.org/docs/current/sql-copy.html
- Postgres TOAST — https://www.postgresql.org/docs/current/storage-toast.html
- Python `re.fullmatch` — https://docs.python.org/3/library/re.html#re.fullmatch
