import csv
import xml.etree.ElementTree as ET

SOURCE = "data/sample_posts.xml"
DEST = "data/expected_posts.csv"

COLUMNS = [
    "Id", "PostTypeId", "ParentId", "AcceptedAnswerId",
    "CreationDate", "Score", "ViewCount", "OwnerUserId",
    "Title", "Tags", "AnswerCount", "CommentCount",
]

def main():
    rows_written = 0

    with open(DEST, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)

        context = ET.iterparse(SOURCE, events=("start", "end"))
        _, root = next(context)

        for event, elem in context:
            if event != "end" or elem.tag != "row":
                continue

            record = [elem.attrib.get(col, "") for col in COLUMNS]
            writer.writerow(record)
            rows_written += 1

            elem.clear()
            root.clear()

    print(f"wrote {rows_written} rows to {DEST}")

if __name__ == "__main__":
    main()