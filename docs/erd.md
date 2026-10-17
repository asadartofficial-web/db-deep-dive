# Entity relationship diagram — `core`

Generated from the database catalogue, not drawn. Every line below is a declared
foreign key in `core`, and every cardinality comes from the nullability of the
referencing column.

## How to read it

Crow's foot notation. The marker nearest an entity says how many of **that**
entity take part. Each marker is two characters: the outer one is the maximum,
the inner one is the minimum.

| marker | means |
|---|---|
| `\|\|` | exactly one |
| `\|o` | zero or one |
| `o{` | zero or more |
| `\|{` | one or more |

A **solid line** is an identifying relationship: the child cannot exist without
the parent, because the parent's key is part of the child's own primary key.
A **dashed line** is non-identifying: the child has its own independent key.

Only `post_tags` is identifying. Every other table carries its own surrogate key.

## The diagram

```mermaid
erDiagram
    users |o..o{ posts      : "owns"
    users |o..o{ posts      : "last edited"
    users |o..o{ comments   : "wrote"
    users |o..o{ badges     : "earned"
    posts |o..o{ posts      : "parent of"
    posts |o..o| posts      : "accepted answer"
    posts |o..o{ comments   : "has"
    posts |o..o{ votes      : "receives"
    posts |o..o{ post_links : "link source"
    posts |o..o{ post_links : "link target"
    posts |o..o| tags       : "tag excerpt"
    posts |o..o| tags       : "tag wiki"
    posts ||--o{ post_tags  : "tagged with"
    tags  ||--o{ post_tags  : "applied to"

    posts {
        bigint    post_key                 PK
        text      site                     UK
        integer   source_id                UK "Id as issued by the site"
        smallint  post_type_id                "1 question 2 answer 3+ other"
        bigint    parent_key               FK "answer to this question"
        bigint    accepted_answer_key      FK
        bigint    owner_user_key           FK
        text      owner_display_name          "kept when the account is gone"
        bigint    last_editor_user_key     FK
        text      last_editor_display_name
        timestamp created_at
        timestamp last_activity_at
        timestamp last_edit_at
        timestamp closed_at
        integer   score
        integer   view_count                  "times this post was read"
        integer   answer_count
        integer   comment_count
        text      title
        text      tags                        "denormalised - see post_tags"
        text      content_license
        boolean   is_deleted                  "true means tombstone row"
    }

    users {
        bigint    user_key       PK
        text      site           UK
        integer   source_id      UK "site-local id starts at -1"
        integer   account_id        "network-wide id - never joins to source_id"
        text      display_name      "a label not an identity"
        timestamp created_at
        timestamp last_access_at
        integer   reputation
        integer   profile_views     "views of the profile not of posts"
        integer   up_votes
        integer   down_votes
        text      location
        text      website_url
        boolean   is_deleted        "true means tombstone row"
    }

    comments {
        bigint    comment_key       PK
        text      site              UK
        integer   source_id         UK
        bigint    post_key          FK
        bigint    user_key          FK
        text      user_display_name    "kept when the account is gone"
        integer   score
        timestamp created_at
        text      comment_text         "capped at 600 chars by the source"
    }

    votes {
        bigint    vote_key     PK
        text      site         UK
        integer   source_id    UK
        bigint    post_key     FK
        smallint  vote_type_id
        timestamp created_at      "date only - time stripped at source"
    }

    badges {
        bigint    badge_key    PK
        text      site         UK
        integer   source_id    UK
        bigint    user_key     FK
        text      badge_name
        timestamp awarded_at
        smallint  badge_class     "1 gold 2 silver 3 bronze"
        boolean   is_tag_based
    }

    tags {
        bigint  tag_key          PK
        text    site             UK
        integer source_id        UK
        text    tag_name         UK "second natural key within a site"
        integer post_count          "count as reported by the source"
        bigint  excerpt_post_key FK
        bigint  wiki_post_key    FK
    }

    post_links {
        bigint    post_link_key    PK
        text      site             UK
        integer   source_id        UK
        bigint    post_key         FK
        bigint    related_post_key FK
        smallint  link_type_id        "1 linked 3 duplicate"
        timestamp created_at
    }

    post_tags {
        bigint post_key PK, FK
        bigint tag_key  PK, FK
    }
```

## What the diagram says that a table list does not

**Almost every relationship is optional.** `|o` rather than `||` on the parent
side of twelve of the fourteen keys. That is not sloppiness — it is the deleted
account and deleted post problem drawn accurately. A post may have no author. A
comment may have no author. The schema has to permit it, so the diagram shows it.

**`post_tags` is the only solid line.** Its two foreign keys are also its primary
key, so a row cannot exist without both parents. That is what an identifying
relationship means, and it is why the junction table needs no surrogate key.

**`posts` points at itself twice.** `parent_key` links an answer to its question.
`accepted_answer_key` links a question to the answer it accepted. A hierarchy and
a one-to-one, in the same table.

**`tags` carries two unique constraints.** `(site, source_id)` and
`(site, tag_name)`. Mermaid marks both with `UK` and cannot show that they are
separate constraints.

**`posts.tags` is a deliberate denormalisation.** The normalised form is
`post_tags`. The string is kept beside it so any row can be traced back to the
dump without a join. It is never read by analysis.

## Regenerating this

```sql
SELECT src.relname, con.conname, con.contype, pg_get_constraintdef(con.oid)
FROM pg_constraint con
JOIN pg_class     src ON src.oid = con.conrelid
JOIN pg_namespace ns  ON ns.oid = src.relnamespace
WHERE ns.nspname = 'core' AND con.contype IN ('f','p','u')
ORDER BY src.relname, con.contype DESC, con.conname;
```

Use `pg_catalog`, not `information_schema`. A read-only role sees no rows in
`information_schema.table_constraints`, because that view requires a privilege
other than `SELECT`.
