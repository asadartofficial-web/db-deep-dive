SET search_path TO :"schema";

UPDATE core.posts AS p
SET parent_key = parent.post_key
FROM staging_posts AS s
JOIN core.posts AS parent
  ON parent.site      = :'schema'
 AND parent.source_id = s.parent_id::INTEGER
WHERE p.site      = :'schema'
  AND p.source_id = s.id::INTEGER;

UPDATE core.posts AS p
SET accepted_answer_key = accepted.post_key
FROM staging_posts AS s
JOIN core.posts AS accepted
  ON accepted.site      = :'schema'
 AND accepted.source_id = s.accepted_answer_id::INTEGER
WHERE p.site      = :'schema'
  AND p.source_id = s.id::INTEGER;