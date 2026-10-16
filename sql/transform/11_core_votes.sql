DROP TABLE IF EXISTS core.votes;

CREATE TABLE core.votes (
    vote_key      BIGSERIAL PRIMARY KEY,
    site          TEXT      NOT NULL,
    source_id     INTEGER   NOT NULL,
    post_key      BIGINT,
    vote_type_id  SMALLINT,
    created_at    TIMESTAMP,
    UNIQUE (site, source_id)
);