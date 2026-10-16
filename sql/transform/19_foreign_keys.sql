BEGIN;

ALTER TABLE core.posts
    ADD CONSTRAINT posts_parent_fk
        FOREIGN KEY (parent_key)           REFERENCES core.posts (post_key),
    ADD CONSTRAINT posts_accepted_answer_fk
        FOREIGN KEY (accepted_answer_key)  REFERENCES core.posts (post_key),
    ADD CONSTRAINT posts_owner_user_fk
        FOREIGN KEY (owner_user_key)       REFERENCES core.users (user_key),
    ADD CONSTRAINT posts_last_editor_user_fk
        FOREIGN KEY (last_editor_user_key) REFERENCES core.users (user_key);

ALTER TABLE core.comments
    ADD CONSTRAINT comments_post_fk FOREIGN KEY (post_key) REFERENCES core.posts (post_key),
    ADD CONSTRAINT comments_user_fk FOREIGN KEY (user_key) REFERENCES core.users (user_key);

ALTER TABLE core.votes
    ADD CONSTRAINT votes_post_fk FOREIGN KEY (post_key) REFERENCES core.posts (post_key);

ALTER TABLE core.badges
    ADD CONSTRAINT badges_user_fk FOREIGN KEY (user_key) REFERENCES core.users (user_key);

ALTER TABLE core.tags
    ADD CONSTRAINT tags_excerpt_post_fk FOREIGN KEY (excerpt_post_key) REFERENCES core.posts (post_key),
    ADD CONSTRAINT tags_wiki_post_fk    FOREIGN KEY (wiki_post_key)    REFERENCES core.posts (post_key);

ALTER TABLE core.post_links
    ADD CONSTRAINT post_links_post_fk         FOREIGN KEY (post_key)         REFERENCES core.posts (post_key),
    ADD CONSTRAINT post_links_related_post_fk FOREIGN KEY (related_post_key) REFERENCES core.posts (post_key);

COMMIT;