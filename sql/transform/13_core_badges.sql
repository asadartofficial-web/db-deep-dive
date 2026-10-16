DROP TABLE IF EXISTS core.badges;

CREATE TABLE core.badges (
    badge_key     BIGSERIAL PRIMARY KEY,
    site          TEXT      NOT NULL,
    source_id     INTEGER   NOT NULL,
    user_key      BIGINT,
    badge_name    TEXT,
    awarded_at    TIMESTAMP,
    badge_class   SMALLINT,
    is_tag_based  BOOLEAN,
    UNIQUE (site, source_id)
);