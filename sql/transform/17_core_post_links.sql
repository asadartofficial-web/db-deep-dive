DROP TABLE IF EXISTS core.post_links;

CREATE TABLE core.post_links (
    post_link_key     BIGSERIAL PRIMARY KEY,
    site              TEXT      NOT NULL,
    source_id         INTEGER   NOT NULL,
    post_key          BIGINT,
    related_post_key  BIGINT,
    link_type_id      SMALLINT,
    created_at        TIMESTAMP,
    UNIQUE (site, source_id)
);