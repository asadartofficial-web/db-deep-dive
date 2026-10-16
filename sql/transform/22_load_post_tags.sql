INSERT INTO core.post_tags (post_key, tag_key)
SELECT p.post_key, t.tag_key
FROM core.posts AS p
CROSS JOIN LATERAL unnest(string_to_array(trim(both '|' FROM p.tags), '|')) AS u(tag_name)
JOIN core.tags AS t
  ON t.site     = p.site
 AND t.tag_name = u.tag_name
WHERE p.tags IS NOT NULL
  AND p.tags <> '';