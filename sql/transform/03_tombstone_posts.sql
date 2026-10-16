SET search_path TO :"schema";

INSERT INTO core.posts (site, source_id, is_deleted)
SELECT :'schema', referenced.source_id, true
FROM (
    SELECT post_id::INTEGER           AS source_id FROM staging_votes      WHERE post_id           IS NOT NULL
    UNION
    SELECT post_id::INTEGER                        FROM staging_comments   WHERE post_id           IS NOT NULL
    UNION
    SELECT post_id::INTEGER                        FROM staging_post_links WHERE post_id           IS NOT NULL
    UNION
    SELECT related_post_id::INTEGER                FROM staging_post_links WHERE related_post_id   IS NOT NULL
    UNION
    SELECT parent_id::INTEGER                      FROM staging_posts      WHERE parent_id         IS NOT NULL
    UNION
    SELECT accepted_answer_id::INTEGER             FROM staging_posts      WHERE accepted_answer_id IS NOT NULL
) AS referenced
WHERE NOT EXISTS (
    SELECT 1
    FROM core.posts p
    WHERE p.site = :'schema'
      AND p.source_id = referenced.source_id
);