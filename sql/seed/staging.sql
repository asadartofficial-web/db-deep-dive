-- Staging tables for the Stack Exchange ingestion.
--
-- Every column is TEXT and nothing is constrained: no primary keys, no NOT NULL,
-- no foreign keys. Staging must never reject a row. Typing and constraints belong
-- to the transform step, where a bad value is a query you can inspect rather than
-- a load that dies on row 4,000,000.
--
-- Column names and order mirror sql/seed/dump_schema.py exactly. Change one,
-- change the other in the same commit. load_dump.py names its columns explicitly
-- in COPY, so a mismatch fails loudly instead of shifting data one column left.
--Ai is used for learning purposes. The data is from Stack Exchange and is used for research and analysis.
-- PostHistory is deliberately absent -- see dump_schema.py.

CREATE SCHEMA IF NOT EXISTS :"schema";
SET search_path TO :"schema";

DROP TABLE IF EXISTS staging_posts;
DROP TABLE IF EXISTS staging_posts_text;
DROP TABLE IF EXISTS staging_users;
DROP TABLE IF EXISTS staging_users_text;
DROP TABLE IF EXISTS staging_comments;
DROP TABLE IF EXISTS staging_votes;
DROP TABLE IF EXISTS staging_badges;
DROP TABLE IF EXISTS staging_tags;
DROP TABLE IF EXISTS staging_post_links;

CREATE TABLE staging_posts (
    id                       TEXT,
    post_type_id             TEXT,
    parent_id                TEXT,
    accepted_answer_id       TEXT,
    creation_date            TEXT,
    last_activity_date       TEXT,
    last_edit_date           TEXT,
    closed_date              TEXT,
    score                    TEXT,
    view_count               TEXT,
    answer_count             TEXT,
    comment_count            TEXT,
    owner_user_id            TEXT,
    owner_display_name       TEXT,
    last_editor_user_id      TEXT,
    last_editor_display_name TEXT,
    title                    TEXT,
    tags                     TEXT,
    content_license          TEXT
);

CREATE TABLE staging_posts_text (
    id                       TEXT,
    body                     TEXT
);

CREATE TABLE staging_users (
    id                       TEXT,
    account_id               TEXT,
    display_name             TEXT,
    creation_date            TEXT,
    last_access_date         TEXT,
    reputation               TEXT,
    views                    TEXT,
    up_votes                 TEXT,
    down_votes               TEXT,
    location                 TEXT,
    website_url              TEXT
);

CREATE TABLE staging_users_text (
    id                       TEXT,
    about_me                 TEXT
);

CREATE TABLE staging_comments (
    id                       TEXT,
    post_id                  TEXT,
    user_id                  TEXT,
    user_display_name        TEXT,
    score                    TEXT,
    creation_date            TEXT,
    comment_text             TEXT
);

CREATE TABLE staging_votes (
    id                       TEXT,
    post_id                  TEXT,
    vote_type_id             TEXT,
    creation_date            TEXT
);

CREATE TABLE staging_badges (
    id                       TEXT,
    user_id                  TEXT,
    name                     TEXT,
    awarded_date             TEXT,
    class                    TEXT,
    tag_based                TEXT
);

CREATE TABLE staging_tags (
    id                       TEXT,
    tag_name                 TEXT,
    post_count               TEXT,
    excerpt_post_id          TEXT,
    wiki_post_id             TEXT
);

CREATE TABLE staging_post_links (
    id                       TEXT,
    post_id                  TEXT,
    related_post_id          TEXT,
    link_type_id             TEXT,
    creation_date            TEXT
);