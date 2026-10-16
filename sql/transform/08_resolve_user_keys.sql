SET search_path TO :"schema";

UPDATE core.posts AS p
SET owner_user_key = u.user_key
FROM staging_posts AS s
JOIN core.users AS u
  ON u.site      = :'schema'
 AND u.source_id = s.owner_user_id::INTEGER
WHERE p.site      = :'schema'
  AND p.source_id = s.id::INTEGER;

UPDATE core.posts AS p
SET last_editor_user_key = u.user_key
FROM staging_posts AS s
JOIN core.users AS u
  ON u.site      = :'schema'
 AND u.source_id = s.last_editor_user_id::INTEGER
WHERE p.site      = :'schema'
  AND p.source_id = s.id::INTEGER;