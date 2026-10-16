SET search_path TO :"schema";

INSERT INTO core.badges (site, source_id, user_key, badge_name, awarded_at, badge_class, is_tag_based)
SELECT
    :'schema',
    b.id::INTEGER,
    u.user_key,
    b.name,
    b.awarded_date::TIMESTAMP,
    b.class::SMALLINT,
    b.tag_based::BOOLEAN
FROM staging_badges AS b
LEFT JOIN core.users AS u
  ON u.site      = :'schema'
 AND u.source_id = b.user_id::INTEGER;