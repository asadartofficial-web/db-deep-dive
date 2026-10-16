SET search_path TO :"schema";

INSERT INTO core.comments (
    site, source_id, post_key, user_key,
    user_display_name, score, created_at, comment_text
)
SELECT
    :'schema',
    c.id::INTEGER,
    p.post_key,
    u.user_key,
    c.user_display_name,
    c.score::INTEGER,
    c.creation_date::TIMESTAMP,
    c.comment_text
FROM staging_comments AS c
LEFT JOIN core.posts AS p
  ON p.site      = :'schema'
 AND p.source_id = c.post_id::INTEGER
LEFT JOIN core.users AS u
  ON u.site      = :'schema'
 AND u.source_id = c.user_id::INTEGER;