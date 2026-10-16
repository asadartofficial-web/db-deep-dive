CREATE SCHEMA IF NOT EXISTS core;

DROP TABLE IF EXISTS core.posts;

CREATE TABLE core.posts (
    -- identity
    post_key                BIGSERIAL PRIMARY KEY,
    site                    TEXT      NOT NULL,
    source_id               INTEGER   NOT NULL,

    -- what kind of post, and what it hangs off
    post_type_id            SMALLINT,
    parent_key              BIGINT,
    accepted_answer_key     BIGINT,

    -- who wrote it
    owner_user_key          BIGINT,
    owner_display_name      TEXT,
    last_editor_user_key    BIGINT,
    last_editor_display_name TEXT,

    -- when
    created_at              TIMESTAMP,
    last_activity_at        TIMESTAMP,
    last_edit_at            TIMESTAMP,
    closed_at               TIMESTAMP,

    -- counts
    score                   INTEGER,
    view_count              INTEGER,
    answer_count            INTEGER,
    comment_count           INTEGER,

    -- content
    title                   TEXT,
    tags                    TEXT,
    content_license         TEXT,

    -- provenance
    is_deleted              BOOLEAN   NOT NULL DEFAULT false,

    UNIQUE (site, source_id)
);