-- Integrity report over one site's staging schema.
-- Read-only. Run before writing any typed-layer DDL: every constraint you plan
-- to declare should be checked here first, because the transform will enforce
-- it whether or not the data agrees.

\timing on
SET search_path TO :"schema";

\echo ''
\echo '=== Key uniqueness ==='
SELECT 'posts'      AS tbl, count(*) AS rows, count(DISTINCT id) AS distinct_ids FROM staging_posts
UNION ALL SELECT 'users',      count(*), count(DISTINCT id) FROM staging_users
UNION ALL SELECT 'comments',   count(*), count(DISTINCT id) FROM staging_comments
UNION ALL SELECT 'votes',      count(*), count(DISTINCT id) FROM staging_votes
UNION ALL SELECT 'badges',     count(*), count(DISTINCT id) FROM staging_badges
UNION ALL SELECT 'tags',       count(*), count(DISTINCT id) FROM staging_tags
UNION ALL SELECT 'post_links', count(*), count(DISTINCT id) FROM staging_post_links;

\echo ''
\echo '=== Type conformance: staging_posts ==='
SELECT
    count(*) FILTER (WHERE id            !~ '^-?\d+$') AS bad_id,
    count(*) FILTER (WHERE post_type_id  !~ '^\d+$')   AS bad_post_type_id,
    count(*) FILTER (WHERE score         !~ '^-?\d+$') AS bad_score,
    count(*) FILTER (WHERE view_count    !~ '^\d+$')   AS bad_view_count,
    count(*) FILTER (WHERE answer_count  !~ '^\d+$')   AS bad_answer_count,
    count(*) FILTER (WHERE creation_date !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}$') AS bad_creation_date,
    count(*) FILTER (WHERE closed_date   !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}$') AS bad_closed_date
FROM staging_posts;

\echo ''
\echo '=== Type conformance: staging_users, staging_badges ==='
SELECT
    count(*) FILTER (WHERE reputation !~ '^-?\d+$') AS bad_reputation,
    count(*) FILTER (WHERE up_votes   !~ '^\d+$')   AS bad_up_votes,
    count(*) FILTER (WHERE account_id !~ '^-?\d+$') AS bad_account_id,
    count(*) FILTER (WHERE account_id IS NULL)      AS null_account_id
FROM staging_users;

SELECT
    count(*) FILTER (WHERE class     !~ '^\d+$')              AS bad_class,
    count(*) FILTER (WHERE tag_based NOT IN ('True','False')) AS bad_tag_based,
    count(DISTINCT tag_based)                                 AS distinct_tag_based
FROM staging_badges;

\echo ''
\echo '=== Orphans: would these foreign keys hold? ==='
SELECT 'posts.owner_user_id -> users.id' AS fk, count(*) AS orphans
FROM staging_posts p
WHERE p.owner_user_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM staging_users u WHERE u.id = p.owner_user_id)

UNION ALL SELECT 'posts.parent_id -> posts.id', count(*)
FROM staging_posts c
WHERE c.parent_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM staging_posts p WHERE p.id = c.parent_id)

UNION ALL SELECT 'posts.accepted_answer_id -> posts.id', count(*)
FROM staging_posts q
WHERE q.accepted_answer_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM staging_posts a WHERE a.id = q.accepted_answer_id)

UNION ALL SELECT 'comments.post_id -> posts.id', count(*)
FROM staging_comments c
WHERE NOT EXISTS (SELECT 1 FROM staging_posts p WHERE p.id = c.post_id)

UNION ALL SELECT 'comments.user_id -> users.id', count(*)
FROM staging_comments c
WHERE c.user_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM staging_users u WHERE u.id = c.user_id)

UNION ALL SELECT 'votes.post_id -> posts.id', count(*)
FROM staging_votes v
WHERE NOT EXISTS (SELECT 1 FROM staging_posts p WHERE p.id = v.post_id)

UNION ALL SELECT 'badges.user_id -> users.id', count(*)
FROM staging_badges b
WHERE NOT EXISTS (SELECT 1 FROM staging_users u WHERE u.id = b.user_id)

UNION ALL SELECT 'post_links.post_id -> posts.id', count(*)
FROM staging_post_links l
WHERE NOT EXISTS (SELECT 1 FROM staging_posts p WHERE p.id = l.post_id)

UNION ALL SELECT 'post_links.related_post_id -> posts.id', count(*)
FROM staging_post_links l
WHERE NOT EXISTS (SELECT 1 FROM staging_posts p WHERE p.id = l.related_post_id);