SET search_path TO :"schema";

INSERT INTO core.users (
    site, source_id, account_id, display_name,
    created_at, last_access_at,
    reputation, profile_views, up_votes, down_votes,
    location, website_url
)
SELECT
    :'schema',
    id::INTEGER,
    account_id::INTEGER,
    display_name,
    creation_date::TIMESTAMP,
    last_access_date::TIMESTAMP,
    reputation::INTEGER,
    views::INTEGER,
    up_votes::INTEGER,
    down_votes::INTEGER,
    location,
    website_url
FROM staging_users;