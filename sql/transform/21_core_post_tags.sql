DROP TABLE IF EXISTS core.post_tags;

CREATE TABLE core.post_tags (
    post_key BIGINT NOT NULL REFERENCES core.posts (post_key),
    tag_key  BIGINT NOT NULL REFERENCES core.tags  (tag_key),
    PRIMARY KEY (post_key, tag_key)
);

CREATE INDEX IF NOT EXISTS post_tags_tag_idx ON core.post_tags (tag_key);