DROP TABLE IF EXISTS core.comments;

CREATE TABLE core.comments (
    comment_key        BIGSERIAL PRIMARY KEY,
    site               TEXT      NOT NULL,
    source_id          INTEGER   NOT NULL,
    post_key           BIGINT,
    user_key           BIGINT,
    user_display_name  TEXT,
    score              INTEGER,
    created_at         TIMESTAMP,
    comment_text       TEXT,
    UNIQUE (site, source_id)
);