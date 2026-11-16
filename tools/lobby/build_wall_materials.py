"""Build wall fill materials from the original private paint, with no uploads.

Roblox only permits plugins to assign EmissiveMaskContent. Serialize the existing
original solid grayscale mask before building the place instead of assigning
it in a game script. Source templates and texture references remain unchanged.
"""
import json
from pathlib import Path
import xml.etree.ElementTree as ET


def generate(source: Path, destination: Path) -> int:
    mask_asset = json.loads((source.parent / "wall-fill-mask.json").read_text())["id"]
    document = ET.parse(source)
    count = 0
    for item in document.findall(".//Item[@class='SurfaceAppearance']"):
        properties = item.find("Properties")
        name = properties.find("string[@name='Name']")
        if name is None or not name.text.startswith("hub-cavern-") or not name.text.endswith("/High"):
            continue
        colour = properties.find("Content[@name='ColorMap']/url")
        assert colour is not None and colour.text, "Wall material has no original paint"
        previous = properties.find("Content[@name='EmissiveMaskContent']")
        if previous is not None:
            properties.remove(previous)
        mask = ET.SubElement(properties, "Content", name="EmissiveMaskContent")
        ET.SubElement(mask, "uri").text = f"rbxassetid://{mask_asset}"
        count += 1
    assert count == 12, f"Expected twelve upper-wall materials, got {count}"
    destination.parent.mkdir(parents=True, exist_ok=True)
    document.write(destination, encoding="utf-8", xml_declaration=True)
    return count
