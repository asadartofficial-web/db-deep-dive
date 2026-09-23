import os
from getpass import getpass
import psycopg2

CSV_PATH = "data/posts_staging.csv"

CONN = {
    "host": "localhost",
    "port": 5432,
    "dbname": "stackexchange",
    "user": "postgres",
    "password": os.environ.get("PGPASSWORD") or getpass("Postgres password: "),
}

COPY_SQL = """
COPY staging_posts (
    id, post_type_id, parent_id, accepted_answer_id,
    creation_date, score, view_count, owner_user_id,
    title, tags, answer_count, comment_count
)
FROM STDIN
WITH (FORMAT csv, NULL '')
"""

def main():
    conn = psycopg2.connect(**CONN)
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute("TRUNCATE staging_posts")

                with open(CSV_PATH, "r", encoding="utf-8", newline="") as f:
                    cur.copy_expert(COPY_SQL, f)

                cur.execute("SELECT count(*) FROM staging_posts")
                print(f"rows in staging_posts: {cur.fetchone()[0]}")
    finally:
        conn.close()

if __name__ == "__main__":
    main()