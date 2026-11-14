-- Index experiments driven by the q01-q05 benchmark set.
-- Applied after the "before" benchmark run; effect measured by the "after" run.
-- Reversible: DROP INDEX core.posts_questions_site_time;

-- q01 / q02 / q03 all filter post_type_id = 1 and aggregate over site + time.
-- The before-run shows every one of them sequential-scanning all of core.posts
-- to keep roughly half the rows. A partial covering index holds only the
-- question rows and everything those queries read, enabling index-only scans.
CREATE INDEX posts_questions_site_time
    ON core.posts (site, created_at)
    INCLUDE (answer_count)
    WHERE post_type_id = 1;

ANALYZE core.posts;
