"""Upload Rammstone's two forms and their image maps as private assets on the owner's account (owner, 2026-11-13: "build
it in Studio", then "do it all").

Reads build/slugs/rammstone/roblox/{base,transformed} (tools/slugs/export_rammstone_roblox.py). The Roblox API key comes
from the existing private client and is never printed. Identical files reuse earlier uploads. Ids and material
templates stay in ignored private-assets/rammstone: RammstoneAsset.luau and materials.rbxmx (a RammstoneMaterials folder
of SurfaceAppearance templates, one per game mesh, cloned onto the imported MeshParts by name).
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
PRIVATE = ROOT/"private-assets/rammstone"
CLIENT = ROOT/"private-assets/floppy/upload_open_cloud.py"
BUILD = ROOT/"build/slugs/rammstone/roblox"
EMISSIVE_FLOOR = 0.0
# form: (body mesh, texture stem, eye mesh prefix)
FORMS = {"base": ("RammstoneBody", "rammstone-base", "RammstoneEye"),
         "transformed": ("RammstoneTransformedBody", "rammstone-transformed", "RammstoneTransformedEye")}


def private_uploader(prefix="Rammstone "):
    """An upload(name, path, asset_type, content_type) function that returns the asset id and skips identical files.
    Reads PRIVATE and BUILD when called, so another slug's uploader can point them at its own folders."""
    PRIVATE.mkdir(parents=True, exist_ok=True)
    sys.argv = ["upload_open_cloud.py", str(BUILD/"base/model.glb")]
    spec = importlib.util.spec_from_file_location("private_upload", CLIENT)
    client = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(client)
    key = client.api_key()
    owner = client.USER_ID
    cache_path = PRIVATE/"assets.json"
    cache = json.loads(cache_path.read_text()) if cache_path.exists() else {}

    def upload(name, path, asset_type, content_type):
        data = path.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        if cache.get(name, {}).get("sha256") == digest:
            return cache[name]["id"]
        request = {"assetType": asset_type, "displayName": prefix + name, "description": "Slugshot private test asset",
                   "creationContext": {"creator": {"userId": str(owner)}}}
        boundary = uuid.uuid4().hex
        body = (f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n'
                f'Content-Type: application/json\r\n\r\n{json.dumps(request)}\r\n'
                f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{path.name}"\r\n'
                f'Content-Type: {content_type}\r\n\r\n').encode() + data + f'\r\n--{boundary}--\r\n'.encode()
        operation = client.call("POST", "https://apis.roblox.com/assets/v1/assets", key, body,
                                "multipart/form-data; boundary=" + boundary)
        operation_id = operation.get("operationId") or operation.get("path", "").split("/")[-1]
        for _ in range(90):
            if operation.get("done"):
                break
            time.sleep(2)
            operation = client.call("GET", "https://apis.roblox.com/assets/v1/operations/" + operation_id, key)
        if not operation.get("done") or operation.get("error"):
            raise RuntimeError("Upload did not complete: " + name)
        cache[name] = {"id": int(operation["response"]["assetId"]), "sha256": digest}
        cache_path.write_text(json.dumps(cache, indent=2) + "\n", encoding="utf-8")
        print("Uploaded:", name, flush=True)
        return cache[name]["id"]
    return upload


def gray(src, dst, channel=None):
    with Image.open(src) as im:
        (im.getchannel(channel) if channel else im.convert("L")).save(dst)
    return dst


def template(folder, name, maps):
    item = ET.SubElement(folder, "Item", {"class": "SurfaceAppearance", "referent": name})
    properties = ET.SubElement(item, "Properties")
    ET.SubElement(properties, "string", name="Name").text = name
    for prop, value in maps.items():
        content = ET.SubElement(properties, "Content", name=prop)
        ET.SubElement(content, "uri" if prop == "EmissiveMaskContent" else "url").text = f"rbxassetid://{value}"


def main():
    upload = private_uploader()
    document = ET.Element("roblox", version="4")
    folder = ET.SubElement(document, "Item", {"class": "Folder", "referent": "materials"})
    ET.SubElement(ET.SubElement(folder, "Properties"), "string", name="Name").text = "RammstoneMaterials"
    lines = ["--!strict", "-- Private model ids for Rammstone's two forms; never commit.", "return {"]
    for form, (mesh, stem, eye) in FORMS.items():
        tex = BUILD/form/"textures"

        def image(name, path):
            return upload(f"{form}-{name}", path, "Image", "image/png")
        template(folder, mesh, {
            "ColorMap": image("color", tex/f"{stem}-color.png"),
            "NormalMap": image("normal", tex/f"{stem}-normal.png"),
            "RoughnessMap": image("roughness", gray(tex/f"{stem}-roughness.png", tex/f"{stem}-roughness-gray.png", "G")),
            "EmissiveMaskContent": image("emissive", gray(tex/f"{stem}-glow.png", tex/f"{stem}-emissive.png")),
        })
        for side in ("L", "R"):
            template(folder, eye + side, {
                "ColorMap": image(f"eye-{side}", tex/f"{stem}-eye-{side}-color.png"),
                "EmissiveMaskContent": image(f"eye-{side}-glow", gray(tex/f"{stem}-eye-{side}-glow.png",
                                                                       tex/f"{stem}-eye-{side}-emissive.png")),
            })
        model = upload(form + "-model", BUILD/form/"model.glb", "Model", "model/gltf-binary")
        lines.append(f"\t{form} = {{ model = {model} }},")
    lines += ["}", ""]
    (PRIVATE/"RammstoneAsset.luau").write_text("\n".join(lines), encoding="utf-8")
    ET.ElementTree(document).write(PRIVATE/"materials.rbxmx", encoding="utf-8", xml_declaration=True)
    print("PASS: Rammstone assets and material templates written privately")


if __name__ == "__main__":
    main()
