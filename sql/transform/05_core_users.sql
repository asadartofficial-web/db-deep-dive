DROP TABLE IF EXISTS core.users;

CREATE TABLE core.users (
    user_key        BIGSERIAL PRIMARY KEY,
    site            TEXT      NOT NULL,
    source_id       INTEGER   NOT NULL,
    account_id      INTEGER,
    display_name    TEXT,
    created_at      TIMESTAMP,
    last_access_at  TIMESTAMP,
    reputation      INTEGER,
    profile_views   INTEGER,
    up_votes        INTEGER,
    down_votes      INTEGER,
    location        TEXT,
    website_url     TEXT,
    is_deleted      BOOLEAN   NOT NULL DEFAULT false,
    UNIQUE (site, source_id)
);