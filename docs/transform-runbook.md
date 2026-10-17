# Transform runbook

How all-`TEXT` staging becomes the typed, constrained `core` layer, and the
decisions behind it.

**Status: complete across three sites** as of 2026-10-16. ~4.77 million rows in
eight tables, fourteen foreign keys, thirteen indexes. Companion to
`docs/ingestion-runbook.md`, which covers everything upstream of this.

## The shape

```
<site>.staging_*  ──►  core.*  (one schema, site as a column)
   all TEXT              typed, keyed, constrained, indexed
   three namespaces      one namespace
```

Staging mirrors the source: three sites, three ID spaces, three schemas. `core`
models reality: one set of tables, a `site` column as an ordinary dimension, and
surrogate keys so the colliding IDs stop colliding.

| File | Role | Runs |
|---|---|---|
| `01_core_posts.sql` | DDL | once |
| `02_load_posts.sql` | staging → core | per site |
| `03_tombstone_posts.sql` | placeholder rows for deleted posts | per site |
| `04_resolve_post_keys.sql` | `parent_key`, `accepted_answer_key` | per site |
| `05`/`06` | `core.users` DDL and load | once / per site |
| `07_tombstone_users.sql` | placeholders for deleted accounts | per site |
| `08_resolve_user_keys.sql` | `owner_user_key`, `last_editor_user_key` | per site |
| `09`–`18` | comments, votes, badges, tags, post_links | once / per site |
| `19_foreign_keys.sql` | twelve FKs, one transaction | once |
| `20_indexes.sql` | twelve indexes + `ANALYZE` | once |
| `21_core_post_tags.sql` | junction table DDL | once |
| `22_load_post_tags.sql` | explodes `posts.tags` into rows | **once, all sites** |

DDL files take no `-v schema=`. Load files take one. Getting that backwards is the
most common mistake in this phase.

`22` is the exception that proves the rule: it reads only from `core`, which
already carries `site` as a column, so one run covers all three sites.

## Decisions

**Surrogate keys, with the natural key retained.** Every table has
`<thing>_key BIGSERIAL PRIMARY KEY` plus `UNIQUE (site, source_id)`. The surrogate
is what joins; the natural key is what traces a row back to the dump. Dropping
`source_id` would make the warehouse unauditable; using it as the key would bring
the collisions back.

**One `core` schema, `site` as a column.** The opposite of the staging decision,
for the opposite reason. Staging inherits IDs, so it needs namespaces. `core`
assigns them, so a `site` column is just a dimension to group by — and
cross-site comparison becomes a `GROUP BY` instead of three queries and a union.

**Tombstones rather than dropped references.** Stack Exchange removes deleted
posts from `Posts.xml` but keeps the votes, comments and links that pointed at
them. 10–20% of `votes.post_id` referenced nothing. Three options were on the
table: drop the orphaned rows, leave the keys NULL, or insert placeholder rows.

Dropping loses 2.25 million votes' worth of signal and biases every aggregate
toward posts that survived moderation. NULLing loses the fact that a reference
existed. A tombstone — `(site, source_id, is_deleted = true)` and nothing else —
keeps the row, keeps the reference valid, and is honest about what is missing.

**120,160 tombstone posts.** 13.9% of coffee, 16.7% of gamedev, 25.1% of gaming.
Same ordering as the measured orphan rates, which is the consistency check.

**Only two tables got tombstones.** Nothing in the nine source tables points at a
comment, vote, badge or link, so those tables need no placeholder rows. Tombstones
exist for tables that are *pointed at*, not for tables in general.

**`LEFT JOIN`, never `JOIN`, when resolving keys.** An inner join silently drops
rows that find no match — it does not error, it returns a smaller result that is
indistinguishable from a correct one. 20,632 comments across the three sites were
written by accounts that no longer have an ID; an inner join would have discarded
every one of them and still printed a clean `INSERT 0 …`.

This cost a real row during the build: a mistyped command skipped
`07_tombstone_users.sql` for coffee, and `08` ran anyway, resolving 4,409 of 4,410
and reporting success. The miss was only visible because the typo itself failed
loudly.

**Names fixed on the way through.** `Users.Views` → `profile_views` (it means
profile views, while `posts.view_count` means post reads — a bare `views` in a
six-table join is a trap). `Badges.Name` → `badge_name`, `Badges.Class` →
`badge_class`. Staging mirrors the source faithfully; `core` is where inherited
names get corrected.

**Two natural keys on `core.tags`.** `UNIQUE (site, source_id)` and
`UNIQUE (site, tag_name)`. Both are true statements about the world — a site
cannot have two tags called `espresso` — so both are declared. A constraint that
holds and is not declared is a fact the database cannot help you with.

**Constraints added last, in one transaction.** Adding a foreign key validates
every existing row once. Having it in place during the load means a lookup on
every one of 4.48 million inserts. All twelve constraints validated in **2,069 ms**
total. `BEGIN`/`COMMIT` around the lot, so there is no half-constrained state.

**Indexes are a separate step, and not optional.** Postgres indexes the
*referenced* side of a foreign key automatically, via the underlying PK or UNIQUE
constraint. It indexes the *referencing* side not at all. Without
`20_indexes.sql`, `core.votes.post_key` holds 2.25 million unindexed values and
every post→votes join, and every delete on `core.posts`, is a sequential scan.
A foreign key buys correctness and zero speed.

**`ANALYZE` after indexing.** `ANALYZE` refreshes the planner's statistics about
each table's size and value distribution. Without it the planner may keep treating
these tables as empty and choose plans accordingly.

## The tags decision

`core.posts.tags` arrives from the dump as one string: `|storage|whole-bean|`.
Faithful to the source, and unqueryable. Three designs were considered.

**A — keep the string, search it with `LIKE`.** No work. No index without a
trigram extension, no way to count tags per post, no join to `core.tags`, no
check that a tag exists, and every analysis re-parses the same text.

**B — a native `TEXT[]` column with a GIN index.** One row per post, no join,
fast lookups, less storage. But arrays are a Postgres feature rather than standard
SQL, no foreign key is possible so a bad tag is never caught, and tag-to-tag
questions get awkward.

**C — a junction table. Chosen.** `core.post_tags (post_key, tag_key)`, 296,562
rows, foreign keys to both parents.

Two reasons C won. First, the whole point of `core` is turning inherited text into
modelled relationships, and `tags` was the last column where that had not happened.
Second, the site-level numbers already showed that tags themselves are worth
asking about — which rules out the design that only answers "does this post have
tag X".

`core.posts.tags` is kept unchanged alongside it, for the same reason
`source_id` is kept: model the data, but keep the raw value so you can trace back.
**This is the project's one deliberate denormalisation.**

**No surrogate key on the junction table.** The pair *is* the row. `(post_key,
tag_key)` is both the primary key and the whole table. A junction table is the one
place where a composite natural key is the right answer.

**Two indexes on it, not one.** The primary key indexes `(post_key, tag_key)` and
answers "which tags does this post have", because it leads with `post_key`. An
index can only be searched from its leading column, so a second index leading with
`tag_key` is needed for "which posts have this tag". A junction table almost
always needs both.

**Foreign keys declared before the load here**, contradicting the rule above. The
inputs are different: `19_foreign_keys.sql` constrained tables loaded from
all-`TEXT` staging, where a bad value was possible. `22` reads only from `core`,
which is already constrained, and a pre-check proved every reference resolved. At
296,562 rows the cost is a fraction of a second either way.

**Profiled before loading, not after.** Before `22` ran, four counts were taken:
296,562 tag uses, 0 tag names absent from `core.tags`, 0 empty strings, 0
duplicate `(post, tag)` pairs. The load was therefore predicted to insert exactly
296,562 rows. It did. A load with a predicted row count is a test; a load without
one is just a load.

## Verified state — 2026-10-16

| table | rows | notes |
|---|---|---|
| `core.posts` | 537,474 | 417,314 real + 120,160 tombstones |
| `core.users` | 363,113 | 363,111 real + 2 tombstones |
| `core.comments` | 576,997 | |
| `core.votes` | 2,251,093 | |
| `core.badges` | 705,058 | |
| `core.tags` | 7,484 | |
| `core.post_links` | 34,519 | |
| `core.post_tags` | 296,562 | 159,100 tagged posts exploded |
| **total** | **4,772,300** | |

Unresolved references after loading: **0** for votes, badges, post_links, and for
`comments.post_key`. Non-zero only where it should be — `comments.user_key` and
`posts.owner_user_key`, where the account genuinely no longer exists.

All fourteen foreign keys applied without a single violation, which is Postgres
independently confirming every orphan count collected by hand.

## Findings

**Deleted-account rate is a platform constant, not a community trait.** Posts with
no identifiable author: 2.6% / 3.1% / 2.8%. Comments with no identifiable author:
2.7% / 3.3% / 3.8%. Two different tables, two different source files, two
independent `LEFT JOIN`s, same answer. Independent paths to the same number is the
strongest evidence available that the pipeline is not lying.

**Deletion rate scales with site age and traffic.** Tombstone share of all post
IDs: coffee 13.9%, gamedev 16.7%, gaming 25.1%. A quarter of every post ID ever
issued on Gaming now points at nothing in the dump.

**Acceptance rate rises with site size; answers per question does not.**

| site | answers | non-answers | answers each | accepted |
|---|---|---|---|---|
| coffee | 2,898 | 1,627 | 1.78 | 42% |
| gamedev | 81,514 | 58,316 | 1.40 | 51% |
| gaming | 163,928 | 109,031 | 1.50 | 56% |

Coffee attracts the most answers per question and accepts the fewest — a small
community where several answers are all defensible.

**Edit rate rises with size**: 38.5% / 40.4% / 44.7% of posts have a recorded
last editor.

**Registered users vastly outnumber posters on a small site.** Coffee has 11,594
users and 4,525 posts — 0.39 posts per user. Gaming has 1.28. Any "average posts
per user" on a site like coffee is meaningless; the distribution is what matters.

**Two sites tag in opposite styles.**

| site | tagged posts | tag uses | tags per post | distinct tags | uses per tag |
|---|---|---|---|---|---|
| coffee | 1,475 | 2,947 | 2.0 | 114 | 25.9 |
| gamedev | 56,729 | 159,441 | 2.8 | 1,113 | 143.3 |
| gaming | 100,896 | 134,174 | 1.3 | 6,257 | 21.4 |

Gamedev uses a small controlled vocabulary heavily — 1,113 tags, 143 uses each.
Gaming uses a large vocabulary thinly — 6,257 tags, 21 uses each, most of them
game titles. Same platform, opposite tagging cultures. The figure is unobtainable
from a pipe-delimited string without parsing it first.

**Our tag counts agree with Stack Exchange's own, to 99.5%.** `core.tags` carries
`post_count` straight from `Tags.xml`. Counting the same thing from
`core.post_tags` gives:

| site | tags | exact match | dump higher | ours higher | total gap |
|---|---|---|---|---|---|
| coffee | 114 | 114 | 0 | 0 | 0 |
| gamedev | 1,113 | 1,056 | 57 | 0 | 81 |
| gaming | 6,257 | 6,227 | 30 | 0 | 39 |

The gaps are tiny and strictly one-directional: 68 tags off by 1, 15 by 2, and
four tags by 3–10. The largest sit on the largest tags — `unity` 16,377 vs 16,367,
`minecraft-java-edition` 13,438 vs 13,433.

That shape — small, one-way, proportional to tag size — is what a few dozen
missing *posts* produce, not a wrong rule. Popular tags are on more posts, so they
are more likely to contain one of the missing ones. Suspected cause: `Posts.xml`
and `Tags.xml` were not exported at the same instant, so a post deleted between
them is gone from one and still counted in the other. **Not proven.** The obvious
test, comparing the latest timestamp in each file, measures last activity rather
than export time and cannot settle it.

This also rules something out: the 120,160 deleted posts are *not* the cause. If
`Tags.xml` still counted them the gap would be in the tens of thousands.

**Open discrepancy.** `docs/ingestion-runbook.md` records answers-per-question as
1.96 / 1.44 / 1.62 from the census; this layer measures 1.78 / 1.40 / 1.50. The
denominators differ — the figures above divide by *non-answers*, which includes
tag wikis and moderator nominations, not by `PostTypeId = 1` alone. Worth
reconciling with an explicit question-only denominator before either number is
quoted anywhere.

## Known gaps

- **120 tag-uses unexplained.** See above. Small enough to ignore for analysis,
  large enough that the cause should be named before anyone quotes tag counts as
  exact.
- **No `marts` layer yet.** `core` is modelled reality; marts are
  question-shaped tables built on top of it.
- **No incremental load.** Every script truncates or recreates. A second dump of
  the same site would require a rebuild, not a merge.
- **Analytical indexes not added.** Only the foreign-key columns are indexed.
  Indexes for `(site, created_at)`, `(site, post_type_id)` and similar should
  follow real queries rather than precede them.
- **`is_deleted` has no counterpart on `core.users`** beyond the two tombstones —
  deleted accounts mostly vanish from references entirely rather than dangling.

## Running it

```powershell
# DDL — once, no schema variable
psql -U postgres -d stackexchange -f .\sql\transform\01_core_posts.sql
psql -U postgres -d stackexchange -f .\sql\transform\05_core_users.sql
psql -U postgres -d stackexchange -f .\sql\transform\09_core_comments.sql
psql -U postgres -d stackexchange -f .\sql\transform\11_core_votes.sql
psql -U postgres -d stackexchange -f .\sql\transform\13_core_badges.sql
psql -U postgres -d stackexchange -f .\sql\transform\15_core_tags.sql
psql -U postgres -d stackexchange -f .\sql\transform\17_core_post_links.sql

# Loads — per site, in this order (posts and users must precede the rest)
foreach ($s in "coffee","gamedev","gaming") {
  foreach ($f in "02_load_posts","03_tombstone_posts","04_resolve_post_keys",
                 "06_load_users","07_tombstone_users","08_resolve_user_keys",
                 "10_load_comments","12_load_votes","14_load_badges",
                 "16_load_tags","18_load_post_links") {
    psql -U postgres -d stackexchange -v schema=$s -f ".\sql\transform\$f.sql"
  }
}

# Constraints and indexes — once, last
psql -U postgres -d stackexchange -f .\sql\transform\19_foreign_keys.sql
psql -U postgres -d stackexchange -f .\sql\transform\20_indexes.sql

# Junction table — once, after core.posts and core.tags both exist
psql -U postgres -d stackexchange -f .\sql\transform\21_core_post_tags.sql
psql -U postgres -d stackexchange -f .\sql\transform\22_load_post_tags.sql
```

Order matters in exactly three places: posts and users must be tombstoned before
anything that references them is loaded, foreign keys must come after everything
they constrain, and `22` needs both `core.posts` and `core.tags` populated.

## Checks

`sql/queries/tag_reference_check.sql` separates *"there was never an excerpt
post"* from *"there was one and we lost it"*. Returns zero on all three sites.

The general shape for any resolve step, using `FILTER (WHERE …)` — a per-aggregate
condition that lets several differently-filtered counts come from one pass:

```sql
SELECT site,
       COUNT(*)                                  AS rows,
       COUNT(*) FILTER (WHERE <key> IS NULL)     AS unresolved
FROM core.<table> GROUP BY site ORDER BY site;
```

A non-zero `unresolved` is not automatically wrong — it is wrong only when the
source column was populated. Those are two different questions and the check has
to ask the second one.

**Inspect constraints through `pg_catalog`, not `information_schema`.** A
read-only role sees zero rows in `information_schema.table_constraints`, because
that view requires a privilege other than `SELECT`. An empty result there looks
exactly like "this schema has no constraints". See `docs/erd.md` for the query.

## Key words

**Surrogate key** — a key the warehouse generates (`BIGSERIAL`), as opposed to one
inherited from the source. What lets three colliding ID spaces share one table.

**Tombstone row** — a placeholder carrying only an identifier and a deleted flag,
inserted so that references to a missing entity stay valid instead of dangling or
disappearing.

**Junction table** — a table whose only job is to record which rows of two other
tables go together, one pair per row. It is how a many-to-many relationship is
stored in a relational database, because neither side can hold a list.

**`unnest`** — a Postgres function that turns one array into several rows. It is
the opposite of an aggregate: `GROUP BY` collapses many rows into one, `unnest`
expands one row into many.

**Referential integrity** — the guarantee that every foreign key value points at a
row that exists. Declared with `FOREIGN KEY`, and enforced by the database on
every write from then on, not just at load time.

**`LEFT JOIN`** — keeps every row of the left table whether or not the right side
matches, filling the missing columns with NULL. The inner `JOIN` silently drops
non-matching rows, which is why it is the wrong default when resolving keys.

## References

- Postgres foreign keys — https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-FK
- Postgres `ALTER TABLE` — https://www.postgresql.org/docs/current/sql-altertable.html
- Postgres array functions and `unnest` — https://www.postgresql.org/docs/current/functions-array.html
- Postgres `LATERAL` subqueries — https://www.postgresql.org/docs/current/queries-table-expressions.html#QUERIES-LATERAL
- Aggregate `FILTER` clause — https://www.postgresql.org/docs/current/sql-expressions.html#SYNTAX-AGGREGATES
- Kimball, surrogate keys in dimensional modelling — https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/
