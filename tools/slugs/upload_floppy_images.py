"""Upload explicit Floppy image maps to bypass unavailable importer texture packs.

Owner-authorized private test asset repair. Credentials and resulting reusable IDs
stay in private-assets/floppy; identical image hashes reuse prior uploads.
"""
import hashlib
import importlib.util
import json
import sys
import time
import uuid
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PRIVATE = ROOT / "private-assets/floppy"
TEXTURES = ROOT / "build/slugs/floppy/roblox/textures"


def main():
    # The existing reviewed private client keeps API-key access out of source.
    sys.argv = ["upload_open_cloud.py", str(TEXTURES / "floppy-body-color.png")]
    spec = importlib.util.spec_from_file_location("private_upload", PRIVATE / "upload_open_cloud.py")
    client = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(client)
    key = client.api_key()
    owner = json.loads((PRIVATE / "roblox_assets.json").read_text())["owner"]
    cache_path = PRIVATE / "image-assets.json"
    cache = json.loads(cache_path.read_text()) if cache_path.exists() else {}
    maps = {"bodyColor": "floppy-body-color.png", "bodyNormal": "floppy-body-normal.png",
            "eyeLColor": "floppy-eye-left.png", "eyeRColor": "floppy-eye-right.png"}
    for tag, filename in (("body", "floppy-body-roughness.png"),
                          ("eyeL", "floppy-eye-roughness-L.png"),
                          ("eyeR", "floppy-eye-roughness-R.png")):
        path = TEXTURES / (tag + "-roughness-gray.png")
        # glTF packs roughness in G; Roblox's separate map must be grayscale.
        with Image.open(TEXTURES / filename) as image:
            image.getchannel("G").save(path)
        maps[tag + "Roughness"] = path.name
    for name, filename in maps.items():
        path = TEXTURES / filename
        data = path.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        if cache.get(name, {}).get("sha256") == digest:
            continue
        request = {"assetType": "Image", "displayName": "Floppy " + name,
                   "description": "Original Floppy test material map",
                   "creationContext": {"creator": {"userId": str(owner)}}}
        boundary = uuid.uuid4().hex
        body = (f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n'
                f'Content-Type: application/json\r\n\r\n{json.dumps(request)}\r\n'
                f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{filename}"\r\n'
                'Content-Type: image/png\r\n\r\n').encode() + data + f'\r\n--{boundary}--\r\n'.encode()
        operation = client.call("POST", "https://apis.roblox.com/assets/v1/assets", key,
                                body, "multipart/form-data; boundary=" + boundary)
        operation_id = operation.get("operationId") or operation.get("path", "").split("/")[-1]
        for _ in range(60):
            if operation.get("done"):
                break
            time.sleep(2)
            operation = client.call("GET", "https://apis.roblox.com/assets/v1/operations/" + operation_id, key)
        if not operation.get("done") or operation.get("error"):
            raise RuntimeError("Image upload did not complete: " + name)
        cache[name] = {"id": int(operation["response"]["assetId"]), "sha256": digest}
        cache_path.write_text(json.dumps(cache, indent=2) + "\n", encoding="utf-8")
        print("Uploaded image map:", name, flush=True)
    assets = json.loads((PRIVATE / "roblox_assets.json").read_text())
    textures = {
        "FloppyBody": {"color": cache["bodyColor"]["id"], "normal": cache["bodyNormal"]["id"],
                       "roughness": cache["bodyRoughness"]["id"]},
        "EyeL": {"color": cache["eyeLColor"]["id"], "roughness": cache["eyeLRoughness"]["id"]},
        "EyeR": {"color": cache["eyeRColor"]["id"], "roughness": cache["eyeRRoughness"]["id"]},
    }
    lines = ["--!strict", "-- Private model and explicit image maps; never commit.",
             "return {", "\tmodel = " + str(assets["model"]) + ",", "\ttextures = {"]
    for name, values in textures.items():
        lines.append("\t\t" + name + " = { " + ", ".join(k + " = " + str(v) for k, v in values.items()) + " },")
    lines += ["\t},", "}", ""]
    (PRIVATE / "FloppyAsset.luau").write_text("\n".join(lines), encoding="utf-8")
    # Serialize preconfigured templates: texture-map setters are plugin-only
    # in Luau, while cloning a prebuilt SurfaceAppearance is supported at runtime.
    document = ET.Element("roblox", version="4")
    folder = ET.SubElement(document, "Item", {"class": "Folder", "referent": "materials"})
    properties = ET.SubElement(folder, "Properties")
    ET.SubElement(properties, "string", name="Name").text = "FloppyMaterials"
    for name, values in textures.items():
        item = ET.SubElement(folder, "Item", {"class": "SurfaceAppearance", "referent": name})
        properties = ET.SubElement(item, "Properties")
        ET.SubElement(properties, "string", name="Name").text = name
        for key, value in values.items():
            property_name = {"color": "ColorMap", "normal": "NormalMap", "roughness": "RoughnessMap"}[key]
            content = ET.SubElement(properties, "Content", name=property_name)
            ET.SubElement(content, "url").text = "rbxassetid://" + str(value)
    ET.ElementTree(document).write(PRIVATE / "materials.rbxmx", encoding="utf-8", xml_declaration=True)
    print("PASS: explicit image mapping and material templates written privately")


if __name__ == "__main__":
    main()
