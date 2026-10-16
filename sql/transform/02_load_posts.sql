SET search_path TO :"schema";

INSERT INTO core.posts (
    site, source_id, post_type_id,
    owner_display_name, last_editor_display_name,
    created_at, last_activity_at, last_edit_at, closed_at,
    score, view_count, answer_count, comment_count,
    title, tags, content_license
)
SELECT
    :'schema',
    id::INTEGER,
    post_type_id::SMALLINT,
    owner_display_name,
    last_editor_display_name,
    creation_date::TIMESTAMP,
    last_activity_date::TIMESTAMP,
    last_edit_date::TIMESTAMP,
    closed_date::TIMESTAMP,
    score::INTEGER,
    view_count::INTEGER,
    answer_count::INTEGER,
    comment_count::INTEGER,
    title,
    tags,
    content_license
FROM staging_posts;