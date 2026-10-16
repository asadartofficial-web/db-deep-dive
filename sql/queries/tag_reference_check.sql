SELECT 'coffee' AS site,
       COUNT(*) FILTER (WHERE s.excerpt_post_id IS NOT NULL AND t.excerpt_post_key IS NULL) AS lost_excerpt,
       COUNT(*) FILTER (WHERE s.wiki_post_id    IS NOT NULL AND t.wiki_post_key    IS NULL) AS lost_wiki
FROM core.tags t JOIN coffee.staging_tags s ON s.id::INTEGER = t.source_id
WHERE t.site = 'coffee'
UNION ALL
SELECT 'gamedev',
       COUNT(*) FILTER (WHERE s.excerpt_post_id IS NOT NULL AND t.excerpt_post_key IS NULL),
       COUNT(*) FILTER (WHERE s.wiki_post_id    IS NOT NULL AND t.wiki_post_key    IS NULL)
FROM core.tags t JOIN gamedev.staging_tags s ON s.id::INTEGER = t.source_id
WHERE t.site = 'gamedev'
UNION ALL
SELECT 'gaming',
       COUNT(*) FILTER (WHERE s.excerpt_post_id IS NOT NULL AND t.excerpt_post_key IS NULL),
       COUNT(*) FILTER (WHERE s.wiki_post_id    IS NOT NULL AND t.wiki_post_key    IS NULL)
FROM core.tags t JOIN gaming.staging_tags s ON s.id::INTEGER = t.source_id
WHERE t.site = 'gaming';