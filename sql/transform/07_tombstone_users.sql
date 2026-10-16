SET search_path TO :"schema";

INSERT INTO core.users (site, source_id, is_deleted)
SELECT :'schema', referenced.source_id, true
FROM (
    SELECT owner_user_id::INTEGER       AS source_id FROM staging_posts    WHERE owner_user_id       IS NOT NULL
    UNION
    SELECT last_editor_user_id::INTEGER              FROM staging_posts    WHERE last_editor_user_id IS NOT NULL
    UNION
    SELECT user_id::INTEGER                          FROM staging_comments WHERE user_id             IS NOT NULL
    UNION
    SELECT user_id::INTEGER                          FROM staging_badges   WHERE user_id             IS NOT NULL
) AS referenced
WHERE NOT EXISTS (
    SELECT 1
    FROM core.users u
    WHERE u.site      = :'schema'
      AND u.source_id = referenced.source_id
);