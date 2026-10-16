SET search_path TO :"schema";

INSERT INTO core.post_links (site, source_id, post_key, related_post_key, link_type_id, created_at)
SELECT
    :'schema',
    l.id::INTEGER,
    p.post_key,
    r.post_key,
    l.link_type_id::SMALLINT,
    l.creation_date::TIMESTAMP
FROM staging_post_links AS l
LEFT JOIN core.posts AS p
  ON p.site      = :'schema'
 AND p.source_id = l.post_id::INTEGER
LEFT JOIN core.posts AS r
  ON r.site      = :'schema'
 AND r.source_id = l.related_post_id::INTEGER;