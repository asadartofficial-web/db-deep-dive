import xml.etree.ElementTree as ET

path = "data/sample_posts.xml"

for event, elem in ET.iterparse(path, events=("end",)):
    if elem.tag != "row":
        continue

    post_id = elem.attrib.get("Id")
    post_type = elem.attrib.get("PostTypeId")
    owner = elem.attrib.get("OwnerUserId")
    tags = elem.attrib.get("Tags")

    print(f"id={post_id} type={post_type} owner={owner} tags={tags}")

    elem.clear()
