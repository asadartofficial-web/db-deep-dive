DROP TABLE IF EXISTS core.tags;

CREATE TABLE core.tags (
    tag_key           BIGSERIAL PRIMARY KEY,
    site              TEXT      NOT NULL,
    source_id         INTEGER   NOT NULL,
    tag_name          TEXT      NOT NULL,
    post_count        INTEGER,
    excerpt_post_key  BIGINT,
    wiki_post_key     BIGINT,
    UNIQUE (site, source_id),
    UNIQUE (site, tag_name)
);