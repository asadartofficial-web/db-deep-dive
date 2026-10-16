SET search_path TO :"schema";

INSERT INTO core.tags (site, source_id, tag_name, post_count, excerpt_post_key, wiki_post_key)
SELECT
    :'schema',
    t.id::INTEGER,
    t.tag_name,
    t.post_count::INTEGER,
    e.post_key,
    w.post_key
FROM staging_tags AS t
LEFT JOIN core.posts AS e
  ON e.site      = :'schema'
 AND e.source_id = t.excerpt_post_id::INTEGER
LEFT JOIN core.posts AS w
  ON w.site      = :'schema'
 AND w.source_id = t.wiki_post_id::INTEGER;