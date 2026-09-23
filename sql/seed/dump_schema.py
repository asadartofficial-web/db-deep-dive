"""The column contract for the Stack Exchange staging load.

One entry per staging table. Everything downstream derives from this file: the
CSV column order, the COPY column list, and the staging DDL. No other script in
the pipeline knows the name of a single Stack Exchange attribute.

Derived from docs/census-coffee.txt -- coffee.stackexchange.com, dump dated
2024-07-04. Re-run the census against any new dump before trusting this.

Each entry declares what happens to every attribute in its source file:

    columns   kept, in this order, in the main staging table
    offload   optional: unbounded text moved to its own table, joined on the key
    ignore    present in the dump and knowingly discarded
    rename    optional: SQL name to use instead of the derived one

An attribute found in the XML and named in none of these is schema drift. The
parser stops on it rather than dropping it silently -- which is why `ignore`
exists as a list rather than as an absence.

PostHistory is deliberately absent. It is 44% of the dump and answers only
questions about edit history, which this project does not ask. Its census is in
docs/census-coffee.txt if that changes. Ai usage cause learning from edits, but the
edits themselves are not the target of this project.
"""

import re

TABLES = {
    "Posts": {
        "table": "staging_posts",
        "columns": [
            "Id", "PostTypeId", "ParentId", "AcceptedAnswerId",
            "CreationDate", "LastActivityDate", "LastEditDate", "ClosedDate",
            "Score", "ViewCount", "AnswerCount", "CommentCount",
            "OwnerUserId", "OwnerDisplayName",
            "LastEditorUserId", "LastEditorDisplayName",
            "Title", "Tags", "ContentLicense",
        ],
        "offload": {
            "table": "staging_posts_text",
            "key": "Id",
            "columns": ["Body"],          # 88.9% of Posts, max 10,215 chars
        },
        "ignore": [
            "FavoriteCount",              # 0.6% -- deprecated in newer dumps
            "CommunityOwnedDate",         # 0.3%
        ],
    },

    "Users": {
        "table": "staging_users",
        "columns": [
            "Id", "AccountId", "DisplayName",
            "CreationDate", "LastAccessDate",
            "Reputation", "Views", "UpVotes", "DownVotes",
            "Location", "WebsiteUrl",
        ],
        "offload": {
            "table": "staging_users_text",
            "key": "Id",
            "columns": ["AboutMe"],       # 60% of Users, max 5,597 chars
        },
        "ignore": [],
    },

    "Comments": {
        "table": "staging_comments",
        "columns": [
            "Id", "PostId", "UserId", "UserDisplayName",
            "Score", "CreationDate", "Text",
        ],
        # Text is 86% of this table but capped at 600 chars by Stack Exchange,
        # below the TOAST threshold -- offloading it would buy a join and nothing else.
        "ignore": [],
        "rename": {"Text": "comment_text"},
    },

    "Votes": {
        "table": "staging_votes",
        "columns": [
            "Id", "PostId", "VoteTypeId", "CreationDate",
        ],
        "ignore": [
            "UserId",                     # 0.1% -- votes are anonymous
            "BountyAmount",               # 0.1%
        ],
    },

    "Badges": {
        "table": "staging_badges",
        "columns": [
            "Id", "UserId", "Name", "Date", "Class", "TagBased",
        ],
        "ignore": [],
        "rename": {"Date": "awarded_date"},
    },

    "Tags": {
        "table": "staging_tags",
        "columns": [
            "Id", "TagName", "Count", "ExcerptPostId", "WikiPostId",
        ],
        "ignore": [],
        "rename": {"Count": "post_count"},
    },

    "PostLinks": {
        "table": "staging_post_links",
        "columns": [
            "Id", "PostId", "RelatedPostId", "LinkTypeId", "CreationDate",
        ],
        "ignore": [],
    },
}


_SPLIT_ACRONYM = re.compile(r"(.)([A-Z][a-z]+)")
_SPLIT_WORD = re.compile(r"([a-z0-9])([A-Z])")


def to_snake(attribute):
    """PascalCase XML attribute -> snake_case SQL column name.

    OwnerUserId -> owner_user_id, UpVotes -> up_votes, Id -> id.
    Two passes: the first splits before a capitalised word, the second splits
    between a lowercase character and a capital. A name this rule handles badly
    goes in the table's `rename` map instead of being special-cased here.
    """
    s = _SPLIT_ACRONYM.sub(r"\1_\2", attribute)
    s = _SPLIT_WORD.sub(r"\1_\2", s)
    return s.lower()


def sql_name(table_key, attribute):
    """The SQL column name for one XML attribute, honouring any rename."""
    return TABLES[table_key].get("rename", {}).get(attribute) or to_snake(attribute)


def source_file(table_key):
    """The XML filename for a table. Derived, so it cannot drift from the key."""
    return f"{table_key}.xml"


def classified(table_key):
    """Every attribute this contract accounts for, in any role.

    The parser subtracts this from what it finds in the XML; whatever remains
    is drift.
    """
    spec = TABLES[table_key]
    names = set(spec["columns"]) | set(spec["ignore"])
    offload = spec.get("offload")
    if offload:
        names |= set(offload["columns"])
    return names