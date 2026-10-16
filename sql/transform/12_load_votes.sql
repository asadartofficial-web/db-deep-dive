SET search_path TO :"schema";

INSERT INTO core.votes (site, source_id, post_key, vote_type_id, created_at)
SELECT
    :'schema',
    v.id::INTEGER,
    p.post_key,
    v.vote_type_id::SMALLINT,
    v.creation_date::TIMESTAMP
FROM staging_votes AS v
LEFT JOIN core.posts AS p
  ON p.site      = :'schema'
 AND p.source_id = v.post_id::INTEGER;